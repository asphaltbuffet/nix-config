# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```go
// GOOD: Tests observable behavior.
func TestUserCanCheckoutWithValidCart(t *testing.T) {
	cart := NewCart()
	cart.Add(product)

	result, err := Checkout(ctx, cart, paymentMethod)

	require.NoError(t, err)
	assert.Equal(t, "confirmed", result.Status)
}
```

Characteristics:

* Tests behavior users/callers care about
* Uses exported API only
* Survives internal refactors
* Describes WHAT, not HOW
* One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```go
// BAD: Tests implementation details.
func TestCheckoutCallsPaymentProcessor(t *testing.T) {
	payment := &mockPaymentProcessor{}

	err := Checkout(ctx, cart, payment)

	require.NoError(t, err)
	assert.Equal(t, 1, payment.processCallCount)
	assert.Equal(t, cart.Total(), payment.processedAmount)
}
```

Red flags:

* Mocking internal collaborators
* Testing unexported functions or methods
* Asserting on call counts/order
* Test breaks when refactoring without behavior change
* Test name describes HOW not WHAT
* Verifying through external means instead of interface

```go
// BAD: Bypasses interface to verify.
func TestCreateUserSavesToDatabase(t *testing.T) {
	_, err := CreateUser(ctx, CreateUserInput{Name: "Alice"})
	require.NoError(t, err)

	row := db.QueryRowContext(ctx, "SELECT name FROM users WHERE name = ?", "Alice")

	var name string
	require.NoError(t, row.Scan(&name))
	assert.Equal(t, "Alice", name)
}
```

```go
// GOOD: Verifies through interface.
func TestCreateUserMakesUserRetrievable(t *testing.T) {
	user, err := CreateUser(ctx, CreateUserInput{Name: "Alice"})
	require.NoError(t, err)

	retrieved, err := GetUser(ctx, user.ID)
	require.NoError(t, err)

	assert.Equal(t, "Alice", retrieved.Name)
}
```
## Prefer Table-Driven Tests

When testing the same behavior across multiple inputs, prefer a table-driven test. This keeps cases easy to add, compare, and name.

```go
// GOOD: Multiple cases share the same test structure.
func TestCartCanCheckout(t *testing.T) {
	tests := []struct {
		name        string
		cart        Cart
		wantStatus  string
		wantErr     bool
	}{
		{
			name:       "valid cart confirms checkout",
			cart:       cartWithProducts(),
			wantStatus: "confirmed",
		},
		{
			name:    "empty cart returns error",
			cart:    NewCart(),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := Checkout(ctx, tt.cart, paymentMethod)

			if tt.wantErr {
				require.Error(t, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.wantStatus, result.Status)
		})
	}
}
```

Characteristics:

* Each case has a clear `name`
* Cases describe behavior, not implementation details
* Setup is shared only when it improves readability
* Expected values are visible in the test table
* New edge cases can be added without copying the whole test

Red flags:

* Table fields that are hard to understand without reading the test body
* Large anonymous setup functions inside each case
* Too many unrelated behaviors in one table
* Hidden expectations inside mocks or closures
* Case names like `"case 1"` or `"error test"`
* Using a table when separate tests would be clearer

