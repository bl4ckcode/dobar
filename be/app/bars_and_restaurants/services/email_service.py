"""
Email service for waitlist notifications.
Uses SendGrid or Mailjet based on environment configuration.
"""
import os
from typing import Optional, Dict, Any
import httpx


# Configuration from environment
EMAIL_PROVIDER = os.getenv("EMAIL_PROVIDER", "sendgrid").lower()
SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
MAILJET_API_KEY = os.getenv("MAILJET_API_KEY")
MAILJET_SECRET = os.getenv("MAILJET_SECRET")
FROM_EMAIL = os.getenv("FROM_EMAIL", "contato@dobar.app")
FROM_NAME = os.getenv("FROM_NAME", "Dobar")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "contato@dobar.app")


async def send_confirmation_email(
    to_email: str,
    contact_name: str,
    bar_name: str,
    city: str
) -> bool:
    """
    Send confirmation email to the user who signed up.
    
    Email is in Portuguese as per the landing page.
    """
    subject = "✅ Você está na lista de espera do Dobar!"
    
    html_content = f"""
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #FFDE59;">Olá {contact_name}!</h2>
            
            <p>Obrigado por se inscrever! O <strong>{bar_name}</strong> está oficialmente na nossa 
            lista de espera para o lançamento em {city}.</p>
            
            <h3 style="color: #0A0A0A;">O que acontece agora?</h3>
            <ol>
                <li>Nossa equipe vai revisar sua inscrição</li>
                <li>Entraremos em contato em até 5 dias úteis</li>
                <li>Se selecionado, você terá acesso antecipado à plataforma</li>
            </ol>
            
            <p>Enquanto isso, siga a gente no Instagram <a href="https://instagram.com/dobar.oficial">@dobar.oficial</a> para novidades.</p>
            
            <p>Dúvidas? Responda este email ou chame no WhatsApp.</p>
            
            <p>Abraço,<br>
            <strong>Time Dobar</strong></p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
            <p style="font-size: 12px; color: #666;">
                Você recebeu este email porque se inscreveu na lista de espera do Dobar.<br>
                Dobar - O Futuro dos Pedidos no Bar
            </p>
        </div>
    </body>
    </html>
    """
    
    text_content = f"""
Olá {contact_name}!

Obrigado por se inscrever! O {bar_name} está oficialmente na nossa 
lista de espera para o lançamento em {city}.

O que acontece agora?
1. Nossa equipe vai revisar sua inscrição
2. Entraremos em contato em até 5 dias úteis
3. Se selecionado, você terá acesso antecipado à plataforma

Enquanto isso, siga a gente no Instagram @dobar.oficial para novidades.

Dúvidas? Responda este email ou chame no WhatsApp.

Abraço,
Time Dobar

---
Você recebeu este email porque se inscreveu na lista de espera do Dobar.
Dobar - O Futuro dos Pedidos no Bar
    """
    
    if EMAIL_PROVIDER == "sendgrid" and SENDGRID_API_KEY:
        return await _send_via_sendgrid(to_email, subject, html_content, text_content)
    elif EMAIL_PROVIDER == "mailjet" and MAILJET_API_KEY and MAILJET_SECRET:
        return await _send_via_mailjet(to_email, subject, html_content, text_content)
    else:
        # Log the email for debugging if no provider configured
        print(f"📧 [EMAIL WOULD BE SENT - No provider configured]")
        print(f"   To: {to_email}")
        print(f"   Subject: {subject}")
        print(f"   Content: {text_content[:200]}...")
        return True


async def send_admin_notification(signup: Dict[str, Any]) -> bool:
    """
    Send notification to admin team about new signup.
    """
    subject = f"🍺 Nova inscrição na lista de espera: {signup['bar_name']}"
    
    html_content = f"""
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #FFDE59;">Nova Inscrição na Lista de Espera!</h2>
            
            <table style="width: 100%; border-collapse: collapse;">
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Bar</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup['bar_name']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Contato</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup['contact_name']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Email</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup['email']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Telefone</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup.get('phone', 'Não informado')}</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Cidade</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup['city']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Fonte</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup.get('source', 'organic')}</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Data</td>
                    <td style="padding: 8px; border: 1px solid #ddd;">{signup.get('created_at', 'Agora')}</td>
                </tr>
            </table>
            
            <p style="margin-top: 20px;">
                <a href="https://api.dobar.com.br/api/v1/admin/waitlist" 
                   style="background-color: #FFDE59; color: #0A0A0A; padding: 12px 24px; 
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Ver Lista Completa
                </a>
            </p>
        </div>
    </body>
    </html>
    """
    
    text_content = f"""
Nova Inscrição na Lista de Espera!

Bar: {signup['bar_name']}
Contato: {signup['contact_name']}
Email: {signup['email']}
Telefone: {signup.get('phone', 'Não informado')}
Cidade: {signup['city']}
Fonte: {signup.get('source', 'organic')}
Data: {signup.get('created_at', 'Agora')}

Ver lista completa: https://api.dobar.com.br/api/v1/admin/waitlist
    """
    
    if EMAIL_PROVIDER == "sendgrid" and SENDGRID_API_KEY:
        return await _send_via_sendgrid(ADMIN_EMAIL, subject, html_content, text_content)
    elif EMAIL_PROVIDER == "mailjet" and MAILJET_API_KEY and MAILJET_SECRET:
        return await _send_via_mailjet(ADMIN_EMAIL, subject, html_content, text_content)
    else:
        print(f"📧 [ADMIN EMAIL WOULD BE SENT - No provider configured]")
        print(f"   To: {ADMIN_EMAIL}")
        print(f"   Subject: {subject}")
        return True


async def _send_via_sendgrid(
    to_email: str,
    subject: str,
    html_content: str,
    text_content: str
) -> bool:
    """Send email via SendGrid API."""
    url = "https://api.sendgrid.com/v3/mail/send"
    
    payload = {
        "personalizations": [
            {
                "to": [{"email": to_email}]
            }
        ],
        "from": {
            "email": FROM_EMAIL,
            "name": FROM_NAME
        },
        "subject": subject,
        "content": [
            {
                "type": "text/plain",
                "value": text_content
            },
            {
                "type": "text/html",
                "value": html_content
            }
        ]
    }
    
    headers = {
        "Authorization": f"Bearer {SENDGRID_API_KEY}",
        "Content-Type": "application/json"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers)
            success = response.status_code == 202
            if success:
                print(f"✅ Email sent successfully to {to_email}")
            else:
                print(f"⚠️ SendGrid error: {response.status_code} - {response.text}")
            return success
        except Exception as e:
            print(f"❌ SendGrid exception sending to {to_email}: {e}")
            return False


async def _send_via_mailjet(
    to_email: str,
    subject: str,
    html_content: str,
    text_content: str
) -> bool:
    """Send email via Mailjet API."""
    url = "https://api.mailjet.com/v3.1/send"
    
    payload = {
        "Messages": [
            {
                "From": {
                    "Email": FROM_EMAIL,
                    "Name": FROM_NAME
                },
                "To": [
                    {
                        "Email": to_email
                    }
                ],
                "Subject": subject,
                "TextPart": text_content,
                "HTMLPart": html_content
            }
        ]
    }
    
    auth = (MAILJET_API_KEY, MAILJET_SECRET)
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, auth=auth)
            if response.status_code == 200:
                print(f"✅ Email sent to {to_email} via Mailjet")
                return True
            else:
                print(f"❌ Mailjet error: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"❌ Failed to send email via Mailjet: {e}")
            return False
