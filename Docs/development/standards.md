# Development standards

Shared rules for backend, frontend, git, and testing so the codebase stays consistent and maintainable.

## Python / Django

- **Style:** Follow PEP 8. Use **Black** for formatting (line length 100) and **isort** for import sorting. Run both before committing (or in CI).
- **Types and docs:** Use type hints on function signatures and docstrings on public functions, classes, and modules. Keep docstrings short; describe what the function does and any non-obvious arguments or side effects.
- **Structure:** No business logic in views. Views delegate to services or serializers; models hold domain logic and validation that is inherently about the data. “Fat models, thin views, smart services.”
- **Example:** A view that creates an order should call something like `OrderService.create_order(store=request.store, payload=serializer.validated_data)` and return a response built from the result. The service handles inventory, totals, and audit; the view does not.

```python
# Good: view delegates to service
def create(self, request, *args, **kwargs):
    serializer = self.get_serializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    order = OrderService.create_order(store=request.store, data=serializer.validated_data)
    return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)
```

- **Imports:** Prefer explicit imports. Avoid `from module import *`. Order: standard library, third-party, local, with isort handling the layout.

## JavaScript / TypeScript

- **Style:** ESLint and Prettier are configured for the frontend. Run `npm run lint` (and fix) before committing.
- **Components:** Use functional components only. No class components. Use hooks for state and side effects.
- **Reuse:** Extract reusable logic into custom hooks (e.g. `useProducts(storeId)`, `useAuth()`). Keep components focused on rendering and event handling.
- **Types:** Use TypeScript strictly. Avoid `any`. Define interfaces or types for props, API responses, and hook return values.
- **Naming:** Use descriptive names. Prefer `isLoading`, `productList` over `flag`, `data` when it clarifies intent.

```typescript
// Good: typed props and return
interface ProductListProps {
  storeId: string;
  onSelect?: (id: string) => void;
}

export function ProductList({ storeId, onSelect }: ProductListProps): JSX.Element {
  const { data, isLoading } = useProducts(storeId);
  // ...
}
```

## Git

- **Branches:** Work from `develop`. Create branches named `feature/<short-name>` or `bugfix/<short-name>`. Use `hotfix/<short-name>` for urgent fixes from `main`.
- **Commits:** Use [Conventional Commits](https://www.conventionalcommits.org/): `feat(scope): description`, `fix(scope): description`, `docs: description`, `refactor(scope): description`, `test(scope): description`, `chore: description`.
- **PRs:** Open PRs into `develop` (or `main` for hotfixes). Require at least one approval. Merge with “squash and merge” to keep history clean. Fill in the PR template.

Examples:  
`feat(products): add bulk CSV import`  
`fix(orders): correct inventory locking on cancel`  
`docs(api): update auth examples`

## Testing

- **Coverage:** Aim for >80% unit test coverage. Critical paths (auth, store access, order creation, payment-related logic) must have tests.
- **Layers:** Unit tests for services, serializers, and utilities; integration tests for API endpoints and store-scoped access; E2E tests for main user journeys (login, create product, place order) where valuable.
- **CI:** All tests run in CI before merge. Tests must not depend on external services (use mocks, fakes, or in-memory DB/Redis where needed).
- **Location:** Backend tests live under `backend/tests/` (unit, integration, fixtures) and can also live next to the app in `apps/<app>/tests/`. Run with `pytest` from the backend directory.
- **Frontend:** Run the test script (e.g. `npm test`) and E2E if configured; they must pass in CI.

These standards are the baseline. New code should follow them; existing code should be brought in line when touched.
