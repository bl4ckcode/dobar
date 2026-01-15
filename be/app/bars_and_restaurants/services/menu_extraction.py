import os
import json
import re
import base64
import tempfile
import httpx
from io import BytesIO
from typing import Optional, Tuple, Dict, List
from urllib.parse import urlparse, urlencode
from google.cloud import vision
from google.oauth2 import service_account
from google.api_core.exceptions import ServiceUnavailable, DeadlineExceeded
import openai

try:
    import fitz
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False

try:
    from bs4 import BeautifulSoup
    BS4_SUPPORT = True
except ImportError:
    BS4_SUPPORT = False


PLATFORM_PATTERNS = {
    "tagme": {
        "domains": ["livemenu.app", "tagme.com.br", "customers.tagme.com.br"],
        "url_pattern": r"/menu/([a-f0-9]{24})",
        "api_template": "https://customers.tagme.com.br/dine-in/menu/{venue_id}/Dine-in?ignoreDisabled=1"
    }
}


EXTRACTION_PROMPT = """You are a menu parser. Extract menu items from the following OCR text.

Rules:
- Group items by category (infer from context if not explicit)
- Extract: name, price (as float), description (if present)
- Handle price formats: R$ 25, 25.00, 25,00, $25, €25
- Detect the currency based on symbols or country context
- Return valid JSON only, no markdown

OCR Text:
{raw_text}

Language hint: {language_hint}

Output format:
{{"currency": "BRL", "categories": [{{"name": "Category", "items": [{{"name": "Item", "price": 0.00, "description": null}}]}}]}}"""


class MenuExtractionService:
    def __init__(self):
        self.vision_client = None
        self.openai_client = None
        self.screenshot_api_key = os.getenv("SCREENSHOT_API_KEY")
    
    def _detect_platform(self, url: str) -> Tuple[Optional[str], Optional[Dict]]:
        parsed = urlparse(url)
        domain = parsed.netloc.lower().replace("www.", "")
        
        for platform_name, config in PLATFORM_PATTERNS.items():
            if any(d in domain for d in config["domains"]):
                match = re.search(config["url_pattern"], url)
                if match:
                    return platform_name, {"venue_id": match.group(1), "config": config}
        
        return None, None
    
    async def _extract_from_tagme(self, platform_data: Dict, language_hint: Optional[str] = None) -> dict:
        venue_id = platform_data["venue_id"]
        api_url = platform_data["config"]["api_template"].format(venue_id=venue_id)
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(api_url)
            response.raise_for_status()
            data = response.json()
        
        categories = []
        currency = "BRL"
        
        for category in data.get("categories", []):
            cat_name = category.get("name", {})
            category_name = cat_name.get(language_hint, "") or cat_name.get("pt", "") or cat_name.get("en", "") or "Menu"
            
            items = []
            for menu in category.get("menus", []):
                for item in menu.get("menuItems", []):
                    item_name_obj = item.get("name", {})
                    item_desc_obj = item.get("description", {})
                    
                    item_name = item_name_obj.get(language_hint, "") or item_name_obj.get("pt", "") or item_name_obj.get("en", "") or "Unknown"
                    item_desc = item_desc_obj.get(language_hint, "") or item_desc_obj.get("pt", "") or item_desc_obj.get("en", "")
                    
                    price = 0.0
                    options = item.get("options", [])
                    if options:
                        price_cents = options[0].get("price", 0)
                        price = price_cents / 100.0
                    
                    items.append({
                        "name": item_name,
                        "price": price,
                        "description": item_desc or None
                    })
            
            if items:
                categories.append({
                    "name": category_name,
                    "items": items
                })
        
        return {
            "confidence": 0.95,
            "categories": categories,
            "raw_text": f"Extracted from TagMe API for venue {venue_id}",
            "currency_detected": currency,
            "extraction_method": "tagme_api"
        }
    
    async def _take_screenshot(self, url: str) -> Optional[bytes]:
        if not self.screenshot_api_key:
            return None
        
        params = {
            "url": url,
            "access_key": self.screenshot_api_key,
            "full_page": "true",
            "format": "png",
            "delay": "3",
            "block_ads": "true",
            "block_cookie_banners": "true"
        }
        
        api_url = f"https://api.screenshotone.com/take?{urlencode(params)}"
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.get(api_url)
            if response.status_code == 200:
                return response.content
        
        return None
    
    def _get_vision_client(self, force_recreate: bool = False):
        if not self.vision_client or force_recreate:
            creds_base64 = os.getenv("GOOGLE_CREDENTIALS_BASE64")
            if creds_base64:
                creds_json = base64.b64decode(creds_base64).decode("utf-8")
                creds_dict = json.loads(creds_json)
                credentials = service_account.Credentials.from_service_account_info(creds_dict)
                self.vision_client = vision.ImageAnnotatorClient(credentials=credentials)
            else:
                self.vision_client = vision.ImageAnnotatorClient()
        return self.vision_client
    
    def _get_openai_client(self):
        if not self.openai_client:
            api_key = os.getenv("OPENAI_API_KEY")
            if not api_key:
                raise ValueError("OPENAI_API_KEY not configured")
            self.openai_client = openai.OpenAI(api_key=api_key)
        return self.openai_client
    
    async def extract_text_from_image(self, image_content: bytes) -> str:
        max_retries = 2
        for attempt in range(max_retries):
            try:
                client = self._get_vision_client(force_recreate=(attempt > 0))
                image = vision.Image(content=image_content)
                response = client.document_text_detection(image=image)
                
                if response.error.message:
                    raise ValueError(f"Vision API error: {response.error.message}")
                
                if not response.full_text_annotation:
                    return ""
                
                return response.full_text_annotation.text
            
            except (ServiceUnavailable, DeadlineExceeded) as e:
                if attempt == max_retries - 1:
                    raise ValueError(f"Google Vision API temporarily unavailable: {str(e)}")
                self.vision_client = None
                continue
    
    async def parse_menu_with_llm(self, raw_text: str, language_hint: Optional[str] = None) -> dict:
        client = self._get_openai_client()
        
        prompt = EXTRACTION_PROMPT.format(
            raw_text=raw_text,
            language_hint=language_hint or "auto-detect"
        )
        
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You extract structured menu data from OCR text. Return only valid JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.1,
            max_tokens=4000
        )
        
        content = response.choices[0].message.content.strip()
        
        if content.startswith("```"):
            content = re.sub(r"^```json?\n?", "", content)
            content = re.sub(r"\n?```$", "", content)
        
        return json.loads(content)
    
    def calculate_confidence(self, raw_text: str, parsed_data: dict) -> float:
        if not parsed_data.get("categories"):
            return 0.0
        
        total_items = sum(len(cat.get("items", [])) for cat in parsed_data["categories"])
        
        if total_items == 0:
            return 0.0
        
        items_with_price = sum(
            1 for cat in parsed_data["categories"]
            for item in cat.get("items", [])
            if item.get("price", 0) > 0
        )
        
        price_ratio = items_with_price / total_items if total_items > 0 else 0
        
        text_length = len(raw_text)
        text_confidence = min(1.0, text_length / 500) if text_length > 50 else 0.3
        
        return round((price_ratio * 0.7 + text_confidence * 0.3), 2)
    
    async def download_from_url(self, url: str) -> tuple[bytes, str]:
        async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
            response = await client.get(url)
            response.raise_for_status()
            
            content_type = response.headers.get("content-type", "").lower()
            
            if "pdf" in content_type or url.lower().endswith(".pdf"):
                return response.content, "pdf"
            elif any(t in content_type for t in ["image/jpeg", "image/png", "image/webp"]):
                return response.content, "image"
            elif url.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                return response.content, "image"
            else:
                return response.content, "html"
    
    async def extract_text_from_pdf(self, pdf_content: bytes) -> str:
        if not PDF_SUPPORT:
            raise ValueError("PDF support not available. Install PyMuPDF: pip install pymupdf")
        
        text_parts = []
        with fitz.open(stream=pdf_content, filetype="pdf") as doc:
            for page in doc:
                text_parts.append(page.get_text())
        
        return "\n".join(text_parts)
    
    async def extract_text_from_html(self, html_content: bytes) -> Tuple[str, bool]:
        text = html_content.decode("utf-8", errors="ignore")
        
        spa_indicators = [
            "<app-root></app-root>",
            'id="root"></div>',
            'id="app"></div>',
            "window.__NUXT__",
            "window.__NEXT_DATA__"
        ]
        is_spa = any(indicator in text for indicator in spa_indicators)
        
        if BS4_SUPPORT:
            soup = BeautifulSoup(text, "html.parser")
            
            for script in soup(["script", "style", "noscript", "header", "footer", "nav"]):
                script.decompose()
            
            schema_data = soup.find("script", {"type": "application/ld+json"})
            if schema_data:
                try:
                    schema = json.loads(schema_data.string)
                    if isinstance(schema, dict) and schema.get("@type") == "Menu":
                        return json.dumps(schema), is_spa
                except:
                    pass
            
            menu_selectors = [
                {"class": re.compile(r"menu|food|dish|item|price", re.I)},
                {"id": re.compile(r"menu|food", re.I)},
            ]
            
            menu_elements = []
            for selector in menu_selectors:
                menu_elements.extend(soup.find_all(True, selector))
            
            if menu_elements:
                text_parts = []
                for elem in menu_elements:
                    text_parts.append(elem.get_text(separator=" ", strip=True))
                extracted = " ".join(text_parts)
                if len(extracted) > 100:
                    return extracted, is_spa
            
            return soup.get_text(separator=" ", strip=True), is_spa
        
        text = re.sub(r"<script[^>]*>.*?</script>", "", text, flags=re.DOTALL | re.IGNORECASE)
        text = re.sub(r"<style[^>]*>.*?</style>", "", text, flags=re.DOTALL | re.IGNORECASE)
        text = re.sub(r"<[^>]+>", " ", text)
        text = re.sub(r"\s+", " ", text)
        return text.strip(), is_spa
    
    async def extract_menu_from_url(self, url: str, language_hint: Optional[str] = None) -> dict:
        platform, platform_data = self._detect_platform(url)
        
        if platform == "tagme":
            try:
                return await self._extract_from_tagme(platform_data, language_hint)
            except Exception:
                pass
        
        content, content_type = await self.download_from_url(url)
        
        if content_type == "image":
            result = await self.extract_menu(content, language_hint)
            result["extraction_method"] = "image_ocr"
            return result
        elif content_type == "pdf":
            raw_text = await self.extract_text_from_pdf(content)
            extraction_method = "pdf"
        elif content_type == "html":
            raw_text, is_spa = await self.extract_text_from_html(content)
            extraction_method = "html"
            
            if is_spa or len(raw_text.strip()) < 100:
                screenshot = await self._take_screenshot(url)
                if screenshot:
                    result = await self.extract_menu(screenshot, language_hint)
                    result["extraction_method"] = "screenshot_ocr"
                    return result
        else:
            raise ValueError(f"Unsupported content type: {content_type}")
        
        if not raw_text or len(raw_text.strip()) < 10:
            raise ValueError("Could not extract text from URL")
        
        parsed_data = await self.parse_menu_with_llm(raw_text, language_hint)
        
        if not parsed_data.get("categories") or all(
            len(cat.get("items", [])) == 0 for cat in parsed_data["categories"]
        ):
            raise ValueError("No menu items detected in content")
        
        confidence = self.calculate_confidence(raw_text, parsed_data)
        
        return {
            "confidence": confidence,
            "categories": parsed_data.get("categories", []),
            "raw_text": raw_text[:5000],
            "currency_detected": parsed_data.get("currency", "BRL"),
            "extraction_method": extraction_method
        }
    
    async def extract_menu(self, image_content: bytes, language_hint: Optional[str] = None) -> dict:
        raw_text = await self.extract_text_from_image(image_content)
        
        if not raw_text or len(raw_text.strip()) < 10:
            raise ValueError("Image quality too low for text extraction")
        
        parsed_data = await self.parse_menu_with_llm(raw_text, language_hint)
        
        if not parsed_data.get("categories") or all(
            len(cat.get("items", [])) == 0 for cat in parsed_data["categories"]
        ):
            raise ValueError("No menu items detected in image")
        
        confidence = self.calculate_confidence(raw_text, parsed_data)
        
        return {
            "confidence": confidence,
            "categories": parsed_data.get("categories", []),
            "raw_text": raw_text,
            "currency_detected": parsed_data.get("currency", "BRL"),
            "extraction_method": "image_ocr"
        }


menu_extraction_service = MenuExtractionService()