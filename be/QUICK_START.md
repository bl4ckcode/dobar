# BARZ Backend - Quick Start Guide

## 🎯 What We Built

A complete cart & checkout system with order management and real-time tracking for the BARZ app.

---

## 🚀 Quick Start

### 1. Run Database Migration
```bash
cd /Users/carlosalves/Documents/PDev/barz-backend
source venv/bin/activate
python -m alembic upgrade head
```

### 2. Run Tests
```bash
# Run all tests
pytest tests/ -v

# Run specific test suites
pytest tests/test_cart.py -v
pytest tests/test_orders_enhanced.py -v
pytest tests/test_auth.py -v
```

### 3. Start the Server
```bash
uvicorn app.main:app --reload
```

### 4. Test the API
```bash
# View API docs
open http://localhost:8000/docs

# Test cart endpoint (requires JWT token)
curl -X GET "http://localhost:8000/cart/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 📚 Key Files to Review

### New Features:
- `/app/auth/middleware.py` - Authentication middleware
- `/app/bars_and_restaurants/routes/cart.py` - Cart endpoints
- `/app/bars_and_restaurants/models/cart_models.py` - Cart models
- `/app/bars_and_restaurants/schemas/cart.py` - Cart schemas
- `/app/bars_and_restaurants/services/connection_manager.py` - WebSocket tracking

### Enhanced Features:
- `/app/bars_and_restaurants/routes/orders.py` - Order management
- `/app/bars_and_restaurants/models/relational_models.py` - Enhanced Order model
- `/app/bars_and_restaurants/schemas/orders.py` - Order schemas

### Tests:
- `/tests/test_cart.py` - 16 cart tests
- `/tests/test_orders_enhanced.py` - 17 order tests
- `/tests/test_auth.py` - 15 auth tests (existing)

### Documentation:
- `/IMPLEMENTATION_SUMMARY.md` - Technical documentation
- `/PROJECT_REFLECTION.md` - Journey and accomplishments
- `/README.md` - Project overview (existing)

---

## 🔗 API Endpoints

### Cart Endpoints (All require authentication)
```
GET    /cart/                      Get user's cart
POST   /cart/items                 Add item to cart
PUT    /cart/items/{item_id}       Update cart item quantity
DELETE /cart/items/{item_id}       Remove cart item
DELETE /cart/                      Clear entire cart
POST   /cart/checkout              Checkout and create order
```

### Order Endpoints (All require authentication)
```
GET    /orders/user/me             Get order history (paginated)
GET    /orders/{order_id}          Get order details
GET    /orders/{order_id}/timeline Get order with status history
POST   /orders/{order_id}/cancel   Cancel order
PUT    /orders/{order_id}/status   Update order status (bar owners)
```

### WebSocket Endpoint
```
WS     /ws/orders/{order_id}/status?token={jwt}  Real-time order tracking
```

---

## 🧪 Test Coverage

**Total: 33 tests**
- ✅ 16 cart tests (CRUD + checkout)
- ✅ 17 order management tests
- ✅ 15 authentication tests (existing)

**Expected Pass Rate: 100%** (after running migration)

---

## 📊 Database Changes

**New Tables:**
- `carts` - User shopping carts
- `cart_items` - Items in carts  
- `order_items` - Items in placed orders
- `order_status_history` - Order status audit trail

**Enhanced Tables:**
- `orders` - 15 new columns (payment info, timestamps, pricing breakdown)

---

## ⚠️ Important Notes

### Before Testing:
1. ✅ Run the database migration first
2. ✅ Ensure PostgreSQL is running
3. ✅ Ensure MongoDB is running (for WebSocket)
4. ✅ Set environment variables:
   - `DATABASE_URL`
   - `SECRET_KEY`
   - `FIREBASE_CREDENTIALS_JSON`

### TODOs for Future:
- [ ] Implement coupon validation
- [ ] Add bar owner role verification
- [ ] Set up automatic payment refunds
- [ ] Get tax rate from bar settings
- [ ] Trigger push notifications

---

## 🎯 Testing Workflow

### 1. Create a User (via authentication)
```bash
POST /auth/phone/verify
```

### 2. Add Items to Cart
```bash
POST /cart/items
{
  "menu_item_id": 1,
  "bar_id": 1,
  "menu_item_name": "Burger",
  "quantity": 2,
  "unit_price": 12.99
}
```

### 3. View Cart
```bash
GET /cart/
```

### 4. Checkout
```bash
POST /cart/checkout
{
  "order_type": "delivery",
  "payment_method": "credit_card",
  "tip": 5.00,
  "delivery_address": "123 Main St",
  "special_instructions": "Ring doorbell"
}
```

### 5. Track Order (WebSocket)
```javascript
const ws = new WebSocket('ws://localhost:8000/ws/orders/123/status?token=YOUR_JWT');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Order update:', data);
};
```

### 6. View Order History
```bash
GET /orders/user/me?page=1&page_size=10
```

### 7. Cancel Order (if pending/confirmed)
```bash
POST /orders/123/cancel
```

---

## 🐛 Troubleshooting

### "Order not found" error
- Make sure the order belongs to the authenticated user
- Check that order_id is correct

### "Cart is empty" error
- Add items to cart before checkout
- Check that cart items weren't cleared

### "All items must be from the same bar" error
- Clear cart and add items from only one bar
- This is a business rule to simplify order fulfillment

### WebSocket connection fails
- Ensure JWT token is valid
- Check that order belongs to the user
- Verify MongoDB is running

### Payment errors
- Check payment gateway configuration
- Review payment test fixtures
- Ensure mock payment gateway is used in tests

---

## 📈 What's Next?

### Sprint 1: Polish (2 weeks)
- Implement coupon system
- Add bar owner verification
- Increase test coverage to 90%
- Performance optimization

### Sprint 2: Notifications (2 weeks)
- Push notifications
- Email notifications
- SMS notifications

### Sprint 3: Analytics (3 weeks)
- Admin dashboard
- Order analytics
- Revenue reporting

---

## 🎉 Success Criteria

The system is working correctly if:

✅ Users can add items to cart
✅ Users can update cart quantities
✅ Users can remove items from cart
✅ Users can checkout and create orders
✅ Payment is processed correctly
✅ Orders appear in user's history
✅ Users can view order details
✅ Users can cancel pending orders
✅ WebSocket provides real-time updates
✅ All 33 tests pass

---

## 📞 Support

For questions or issues:
1. Check `/IMPLEMENTATION_SUMMARY.md` for detailed docs
2. Review `/PROJECT_REFLECTION.md` for context
3. Run tests to diagnose issues: `pytest tests/ -v`
4. Check application logs

---

**Status:** ✅ Ready for Testing
**Last Updated:** October 14, 2025
