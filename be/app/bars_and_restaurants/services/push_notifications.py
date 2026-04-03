"""
🔔 Firebase Cloud Messaging (FCM) Push Notification Service

This service handles sending push notifications to mobile devices.
It's used as a backup/complement to WebSockets for critical events
like new orders, order ready, and payment confirmations.

Cost: FREE (Firebase FCM is free for any volume)

Setup:
1. Create Firebase project at https://console.firebase.google.com
2. Download service account JSON
3. Set FIREBASE_CREDENTIALS_PATH in .env

Usage:
    from app.bars_and_restaurants.services.push_notifications import push_service
    
    # Send to specific device
    await push_service.send_to_device(
        token="device_fcm_token",
        title="Order Ready!",
        body="Your order #123 is ready for pickup",
        data={"order_id": "123", "action": "order_ready"}
    )
    
    # Send to topic (all bar owners subscribed to a bar)
    await push_service.send_to_topic(
        topic=f"bar_{bar_id}_orders",
        title="New Order!",
        body="You have a new order waiting",
        data={"order_id": "456", "action": "new_order"}
    )
"""

import os
import json
import asyncio
import logging
from typing import Optional, Dict, List
from datetime import datetime, timezone

# Setup logger
logger = logging.getLogger(__name__)

# Firebase Admin SDK
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print("⚠️ firebase-admin not installed. Push notifications disabled.")
    print("   Install with: pip install firebase-admin")


class PushNotificationService:
    """
    Firebase Cloud Messaging service for push notifications.
    
    Supports:
    - Device tokens (individual users)
    - Topics (groups of users, e.g., bar owners for a specific bar)
    - Multicast (up to 500 tokens at once)
    """
    
    def __init__(self):
        self.initialized = False
        self.app = None
        
    def initialize(self):
        """Initialize Firebase Admin SDK."""
        if not FIREBASE_AVAILABLE:
            print("⚠️ Firebase Admin SDK not available")
            return False
            
        if self.initialized:
            return True
            
        try:
            # Try to get credentials from environment
            creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
            creds_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
            
            if creds_path and os.path.exists(creds_path):
                cred = credentials.Certificate(creds_path)
            elif creds_json:
                cred_dict = json.loads(creds_json)
                cred = credentials.Certificate(cred_dict)
            else:
                print("⚠️ Firebase credentials not found. Set FIREBASE_CREDENTIALS_PATH or FIREBASE_CREDENTIALS_JSON")
                return False
            
            # Initialize the app (only once)
            try:
                self.app = firebase_admin.get_app()
            except ValueError:
                self.app = firebase_admin.initialize_app(cred)
            
            self.initialized = True
            print("✅ Firebase Admin SDK initialized")
            return True
            
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
            return False
    
    async def send_to_device(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
        image_url: Optional[str] = None,
        priority: str = "high"
    ) -> dict:
        """
        Send a push notification to a specific device.
        
        Args:
            token: FCM device token
            title: Notification title
            body: Notification body text
            data: Custom data payload (key-value pairs, all strings)
            image_url: URL of image to display
            priority: "high" or "normal"
            
        Returns:
            dict with success status and message_id or error
        """
        if not self.initialized:
            if not self.initialize():
                return {"success": False, "error": "Firebase not initialized"}
        
        try:
            # Build the message
            notification = messaging.Notification(
                title=title,
                body=body,
                image=image_url
            )
            
            # Android-specific config
            android_config = messaging.AndroidConfig(
                priority=priority,
                notification=messaging.AndroidNotification(
                    icon="notification_icon",
                    color="#FF6B00",  # BARZ orange
                    sound="default",
                    click_action="FLUTTER_NOTIFICATION_CLICK"
                )
            )
            
            # iOS-specific config
            apns_config = messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(
                            title=title,
                            body=body
                        ),
                        sound="default",
                        badge=1
                    )
                )
            )
            
            message = messaging.Message(
                notification=notification,
                data=data or {},
                android=android_config,
                apns=apns_config,
                token=token
            )
            
            # Send asynchronously
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None, 
                messaging.send, 
                message
            )
            
            return {
                "success": True,
                "message_id": response,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            
        except messaging.UnregisteredError:
            return {"success": False, "error": "Device token is invalid or unregistered"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def send_to_topic(
        self,
        topic: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
        image_url: Optional[str] = None
    ) -> dict:
        """
        Send a push notification to all devices subscribed to a topic.
        
        Topics are useful for:
        - Bar owners: Subscribe to "bar_{bar_id}_orders"
        - Users near a bar: Subscribe to "bar_{bar_id}_promotions"
        
        Args:
            topic: Topic name (e.g., "bar_123_orders")
            title: Notification title
            body: Notification body text
            data: Custom data payload
            image_url: URL of image to display
            
        Returns:
            dict with success status and message_id or error
        """
        if not self.initialized:
            if not self.initialize():
                return {"success": False, "error": "Firebase not initialized"}
        
        try:
            notification = messaging.Notification(
                title=title,
                body=body,
                image=image_url
            )
            
            message = messaging.Message(
                notification=notification,
                data=data or {},
                topic=topic
            )
            
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                messaging.send,
                message
            )
            
            return {
                "success": True,
                "message_id": response,
                "topic": topic,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def send_multicast(
        self,
        tokens: List[str],
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None
    ) -> dict:
        """
        Send a notification to multiple devices at once (max 500).
        
        Args:
            tokens: List of FCM device tokens (max 500)
            title: Notification title
            body: Notification body text
            data: Custom data payload
            
        Returns:
            dict with success_count, failure_count, and responses
        """
        if not self.initialized:
            if not self.initialize():
                return {"success": False, "error": "Firebase not initialized"}
        
        if len(tokens) > 500:
            return {"success": False, "error": "Maximum 500 tokens per multicast"}
        
        try:
            notification = messaging.Notification(title=title, body=body)
            
            message = messaging.MulticastMessage(
                notification=notification,
                data=data or {},
                tokens=tokens
            )
            
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                messaging.send_each_for_multicast,
                message
            )
            
            return {
                "success": True,
                "success_count": response.success_count,
                "failure_count": response.failure_count,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def subscribe_to_topic(self, tokens: List[str], topic: str) -> dict:
        """
        Subscribe devices to a topic.
        
        Usage:
            # Bar owner subscribes to their bar's orders
            await push_service.subscribe_to_topic(
                tokens=[device_token],
                topic=f"bar_{bar_id}_orders"
            )
        """
        if not self.initialized:
            if not self.initialize():
                return {"success": False, "error": "Firebase not initialized"}
        
        try:
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                messaging.subscribe_to_topic,
                tokens,
                topic
            )
            
            return {
                "success": True,
                "success_count": response.success_count,
                "failure_count": response.failure_count,
                "topic": topic
            }
            
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def unsubscribe_from_topic(self, tokens: List[str], topic: str) -> dict:
        """Unsubscribe devices from a topic."""
        if not self.initialized:
            if not self.initialize():
                return {"success": False, "error": "Firebase not initialized"}
        
        try:
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                messaging.unsubscribe_from_topic,
                tokens,
                topic
            )
            
            return {
                "success": True,
                "success_count": response.success_count,
                "failure_count": response.failure_count,
                "topic": topic
            }
            
        except Exception as e:
            return {"success": False, "error": str(e)}


# Singleton instance
push_service = PushNotificationService()


# =============================================================================
# CONVENIENCE FUNCTIONS FOR BARZ-SPECIFIC NOTIFICATIONS
# =============================================================================

async def notify_new_order_push(
    bar_id: int,
    bar_name: str,
    order_id: int,
    total_price: float,
    owner_device_tokens: Optional[List[str]] = None
):
    """
    Send push notification for new order to bar owner.
    
    Uses both topic (bar_{bar_id}_orders) and direct tokens if available.
    """
    topic = f"bar_{bar_id}_orders"
    title = "🔔 New Order!"
    body = f"New order #{order_id} - R$ {total_price:.2f}"
    data = {
        "action": "new_order",
        "order_id": str(order_id),
        "bar_id": str(bar_id),
        "click_action": "OPEN_ORDER_DETAILS"
    }
    
    # Send to topic (all devices subscribed)
    result = await push_service.send_to_topic(
        topic=topic,
        title=title,
        body=body,
        data=data
    )
    
    # Also send to specific tokens if provided
    if owner_device_tokens:
        await push_service.send_multicast(
            tokens=owner_device_tokens,
            title=title,
            body=body,
            data=data
        )
    
    return result


async def notify_order_ready_push(
    user_device_token: str,
    user_id: int,
    order_id: int,
    bar_name: str
):
    """Send push notification to user when their order is ready and persist it."""
    title = "🎉 Order Ready!"
    body = f"Your order #{order_id} at {bar_name} is ready for pickup!"
    
    try:
        from app.database import database
        from app.bars_and_restaurants.models.relational_models import Notification
        
        insert_stmt = Notification.__table__.insert().values(
            user_id=user_id,
            title=title,
            message=body,
            notification_type="order_update",
            reference_id=str(order_id)
        )
        await database.execute(insert_stmt)
    except Exception as e:
        logger.error(f"Failed to persist notification: {e}")
        
    return await push_service.send_to_device(
        token=user_device_token,
        title=title,
        body=body,
        data={
            "action": "order_ready",
            "order_id": str(order_id),
            "click_action": "OPEN_ORDER_STATUS"
        }
    )


async def notify_order_status_push(
    user_device_token: str,
    user_id: int,
    order_id: int,
    status: str,
    bar_name: str
):
    """Send push notification for order status change and persist it."""
    status_messages = {
        "confirmed": ("✅ Order Confirmed", f"{bar_name} confirmed your order #{order_id}"),
        "preparing": ("👨‍🍳 Preparing", f"Your order #{order_id} is being prepared"),
        "ready": ("🎉 Ready!", f"Your order #{order_id} is ready for pickup!"),
        "completed": ("✨ Completed", f"Order #{order_id} completed. Thanks for visiting {bar_name}!"),
        "cancelled": ("❌ Cancelled", f"Order #{order_id} was cancelled")
    }
    
    title, body = status_messages.get(status, ("Order Update", f"Order #{order_id} status: {status}"))
    
    try:
        from app.database import database
        from app.bars_and_restaurants.models.relational_models import Notification
        
        insert_stmt = Notification.__table__.insert().values(
            user_id=user_id,
            title=title,
            message=body,
            notification_type="order_update",
            reference_id=str(order_id)
        )
        await database.execute(insert_stmt)
    except Exception as e:
        logger.error(f"Failed to persist notification: {e}")
    
    return await push_service.send_to_device(
        token=user_device_token,
        title=title,
        body=body,
        data={
            "action": "order_status",
            "order_id": str(order_id),
            "status": status,
            "click_action": "OPEN_ORDER_STATUS"
        }
    )


async def notify_payment_success_push(
    user_device_token: str,
    user_id: int,
    order_id: int,
    amount: float
):
    """Send push notification for successful payment and persist it."""
    title = "💳 Payment Confirmed"
    body = f"Payment of R$ {amount:.2f} for order #{order_id} was successful!"
    
    try:
        from app.database import database
        from app.bars_and_restaurants.models.relational_models import Notification
        
        insert_stmt = Notification.__table__.insert().values(
            user_id=user_id,
            title=title,
            message=body,
            notification_type="system",
            reference_id=str(order_id)
        )
        await database.execute(insert_stmt)
    except Exception as e:
        logger.error(f"Failed to persist notification: {e}")
        
    return await push_service.send_to_device(
        token=user_device_token,
        title=title,
        body=body,
        data={
            "action": "payment_success",
            "order_id": str(order_id),
            "amount": str(amount),
            "click_action": "OPEN_ORDER_STATUS"
        }
    )


async def notify_promotion_push(
    bar_id: int,
    bar_name: str,
    promo_title: str,
    promo_id: int
):
    """Send push notification about new promotion to users near the bar."""
    topic = f"bar_{bar_id}_promotions"
    
    return await push_service.send_to_topic(
        topic=topic,
        title=f"🎁 {bar_name}",
        body=promo_title,
        data={
            "action": "new_promotion",
            "bar_id": str(bar_id),
            "promotion_id": str(promo_id),
            "click_action": "OPEN_PROMOTION"
        }
    )
