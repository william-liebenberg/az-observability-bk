import { configureTelemetry } from "./shared/telemetry";

configureTelemetry();

import "./functions/httpOrders";
import "./functions/processCoffeeOrders";
import "./functions/receiptBlobTrigger";
import "./functions/orderChangeFeed";
