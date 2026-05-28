# When to Mock

Mock at **system boundaries** only:

- External APIs and services (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Non-deterministic (time, randomness, etc.)
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design small interfaces that are easy to fake in tests:

**1. Use dependency injection**

Pass external dependencies in rather than creating them inside business logic:

```go
// Easy to test
type PaymentCharger interface {
	Charge(ctx context.Context, amountCents int64) error
}

type PaymentService struct {
	charger PaymentCharger
}

func (s PaymentService) ProcessPayment(ctx context.Context, order Order) error {
	return s.charger.Charge(ctx, order.TotalCents)
}

// In tests, use a small fake.
type fakeCharger struct {
	chargedAmount int64
	err           error
}

func (f *fakeCharger) Charge(ctx context.Context, amountCents int64) error {
	f.chargedAmount = amountCents
	return f.err
}
````

```go
// Hard to test
func ProcessPayment(ctx context.Context, order Order) error {
	client := stripe.NewClient(os.Getenv("STRIPE_KEY"))
	return client.Charge(ctx, order.TotalCents)
}
```

**2. Prefer narrow domain interfaces over generic clients**

Define methods for the operations the code actually needs instead of one generic `Do`/`Fetch` method with conditional logic:

```go
// GOOD: Each method is independently fakeable
type StoreAPI interface {
	GetUser(ctx context.Context, id string) (User, error)
	ListOrders(ctx context.Context, userID string) ([]Order, error)
	CreateOrder(ctx context.Context, order NewOrder) (Order, error)
}
```

```go
// BAD: Fakes need endpoint routing and conditional logic
type HTTPClient interface {
	Do(ctx context.Context, method string, path string, body any) ([]byte, error)
}
```

The domain-interface approach means:

* Each fake method returns one specific shape
* No endpoint-routing logic in test setup
* Easier to see which external operations a test exercises
* Compile-time types for each operation
* Business logic stays separate from HTTP, SDK, and environment details

