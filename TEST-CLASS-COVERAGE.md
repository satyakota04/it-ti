# Classes covered by each IT (disjoint file sets)

Legend: **A** = order-service, **B** = inventory-service, **C** = shipping-service.

Each IT owns a **pairwise-disjoint** set of source files under `com.harness.sample.*` so TI file-based selection maps a changed file to exactly one test.

---

## `SelectAbcIT` — `combination_ABC_orderViaInventoryAndShipping`

**Chain:** A → B → C  
**Entry:** `POST /orders` then `GET /orders/{id}`

```
IT → order POST /orders
       → inventory GET /stock/{sku}
            → shipping GET /eta/{sku}
IT → order GET /orders/{id}
```

### Order (A)

| Class | Role |
|-------|------|
| `com.harness.sample.order.OrderController` | `createOrder`, `getOrder` |
| `com.harness.sample.order.OrderService` | `createOrder`, `getOrder` |
| `com.harness.sample.order.InventoryClient` | `checkStock` → B |
| `com.harness.sample.order.OrderRepository` | `save`, `findById` |
| `com.harness.sample.order.Order` | order entity |
| `com.harness.sample.order.OrderController.CreateOrderRequest` | request DTO |
| `com.harness.sample.order.InventoryClient.StockInfo` | response DTO from B |

### Inventory (B)

| Class | Role |
|-------|------|
| `com.harness.sample.inventory.StockController` | `getStock` |
| `com.harness.sample.inventory.StockService` | `getStock`, `calculateQuantity` |
| `com.harness.sample.inventory.ShippingClient` | `getEta` → C |
| `com.harness.sample.inventory.StockItem` | stock response |

### Shipping (C)

| Class | Role |
|-------|------|
| `com.harness.sample.shipping.ShippingHandler` | `getEta` |
| `com.harness.sample.shipping.EtaCalculator` | `calculate` |
| `com.harness.sample.shipping.ShippingHandler.EtaResponse` | response DTO |

---

## `SelectBacIT` — `combination_BAC_inventoryStockOrderViaOrder`

**Chain:** B → A → C  
**Entry:** `GET /stock-order/{sku}`

```
IT → inventory GET /stock-order/{sku}
       → order GET /orders/eta/{sku}
            → shipping GET /priority-eta/{sku}
```

### Inventory (B)

| Class | Role |
|-------|------|
| `com.harness.sample.inventory.StockOrderController` | `getStockWithOrder` |
| `com.harness.sample.inventory.StockOrderService` | `getStockWithOrder`, `calculateQuantity` |
| `com.harness.sample.inventory.OrderClient` | `getEta` → A |
| `com.harness.sample.inventory.StockOrderItem` | stock-order response |

### Order (A)

| Class | Role |
|-------|------|
| `com.harness.sample.order.OrderEtaController` | `getEta` |
| `com.harness.sample.order.OrderEtaService` | `getEta` |
| `com.harness.sample.order.ShippingClient` | `getEta` → C |
| `com.harness.sample.order.OrderEtaController.EtaResponse` | response DTO |

### Shipping (C)

| Class | Role |
|-------|------|
| `com.harness.sample.shipping.PriorityEtaHandler` | `getPriorityEta` |
| `com.harness.sample.shipping.PriorityEtaCalculator` | `calculate` |
| `com.harness.sample.shipping.PriorityEtaHandler.PriorityEtaResponse` | response DTO |

---

## `SelectCabIT` — `combination_CAB_shippingShipOrderViaOrder`

**Chain:** C → A → B  
**Entry:** `GET /ship-order/{sku}`

```
IT → shipping GET /ship-order/{sku}
       → order GET /orders/lookup/{sku}
            → inventory GET /qty/{sku}
```

### Shipping (C)

| Class | Role |
|-------|------|
| `com.harness.sample.shipping.ShipOrderHandler` | `shipOrder` |
| `com.harness.sample.shipping.OrderClient` | `lookupOrder` → A |
| `com.harness.sample.shipping.ShipOrderHandler.ShipOrderResponse` | response DTO |

### Order (A)

| Class | Role |
|-------|------|
| `com.harness.sample.order.OrderLookupController` | `lookupBySku` |
| `com.harness.sample.order.OrderLookupService` | `lookupBySku` |
| `com.harness.sample.order.LookupInventoryClient` | `getQty` → B |
| `com.harness.sample.order.OrderLookupService.LookupResult` | lookup response |
| `com.harness.sample.order.LookupInventoryClient.QtyInfo` | response DTO from B |

### Inventory (B)

| Class | Role |
|-------|------|
| `com.harness.sample.inventory.QtyController` | `getQty` |
| `com.harness.sample.inventory.QtyService` | `getQty`, `calculateQuantity` |
| `com.harness.sample.inventory.QtyItem` | qty response |

---

## Disjoint file matrix

| Class | AbcIT | BacIT | CabIT |
|-------|:-----:|:-----:|:-----:|
| **Order (A)** | | | |
| `order.OrderController` | ✓ | | |
| `order.OrderService` | ✓ | | |
| `order.InventoryClient` | ✓ | | |
| `order.OrderRepository` | ✓ | | |
| `order.Order` | ✓ | | |
| `order.OrderEtaController` | | ✓ | |
| `order.OrderEtaService` | | ✓ | |
| `order.ShippingClient` | | ✓ | |
| `order.OrderLookupController` | | | ✓ |
| `order.OrderLookupService` | | | ✓ |
| `order.LookupInventoryClient` | | | ✓ |
| **Inventory (B)** | | | |
| `inventory.StockController` | ✓ | | |
| `inventory.StockService` | ✓ | | |
| `inventory.ShippingClient` | ✓ | | |
| `inventory.StockItem` | ✓ | | |
| `inventory.StockOrderController` | | ✓ | |
| `inventory.StockOrderService` | | ✓ | |
| `inventory.OrderClient` | | ✓ | |
| `inventory.StockOrderItem` | | ✓ | |
| `inventory.QtyController` | | | ✓ |
| `inventory.QtyService` | | | ✓ |
| `inventory.QtyItem` | | | ✓ |
| **Shipping (C)** | | | |
| `shipping.ShippingHandler` | ✓ | | |
| `shipping.EtaCalculator` | ✓ | | |
| `shipping.PriorityEtaHandler` | | ✓ | |
| `shipping.PriorityEtaCalculator` | | ✓ | |
| `shipping.ShipOrderHandler` | | | ✓ |
| `shipping.OrderClient` | | | ✓ |

No class appears in more than one column.

---

## Selection verification

After a full CG upload, change only one owned file and confirm TI select returns a single IT:

1. Change `order/InventoryClient.java` → **only** `SelectAbcIT`
2. Change `inventory/StockOrderController.java` → **only** `SelectBacIT`
3. Change `shipping/ShipOrderHandler.java` → **only** `SelectCabIT`
