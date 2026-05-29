# Interface Design for Testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them**

   ```go
   // Testable
   func ProcessOrder(order Order, paymentGateway *Gateway) {}

   // Hard to test
   func processOrder(order int) {
     gateway := new stripe.Gateway()
   }
   ```

2. **Return results, don't produce side effects**

   ```go
   // Testable
   func CalculateDiscount(cart *Cart) float64 {}

   // Hard to test
   func applyDiscount(cart *Cart) {
     cart.Total -= discount;
   }
   ```

3. **Small surface area**
   - Fewer methods = fewer tests needed
   - Fewer params = simpler test setup
