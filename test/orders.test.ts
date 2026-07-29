import assert from "node:assert/strict";
import test from "node:test";
import { validateOrder } from "../src/services/orders";

test("validateOrder trims required fields and defaults the size", () => {
  assert.deepEqual(
    validateOrder({ customerName: "  Ada  ", drink: "  flat white  " }),
    {
      customerName: "Ada",
      drink: "flat white",
      size: "medium"
    }
  );
});

test("validateOrder rejects missing required fields", () => {
  assert.throws(
    () => validateOrder({ drink: "latte" }),
    /customerName is required/
  );
  assert.throws(
    () => validateOrder({ customerName: "Ada" }),
    /drink is required/
  );
});

test("validateOrder rejects unsupported sizes", () => {
  assert.throws(
    () => validateOrder({
      customerName: "Ada",
      drink: "latte",
      size: "extra-large" as never
    }),
    /size must be one of/
  );
});
