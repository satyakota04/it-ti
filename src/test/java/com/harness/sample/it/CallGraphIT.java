package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.testng.annotations.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Slim call-graph (CG) suite.
 * A = order-service, B = inventory-service, C = shipping-service.
 * Covers A→B→C and A↔B combinations only.
 */
public class CallGraphIT {
    private static final Properties SERVICES = loadServices();
    private static final String ORDER_SERVICE_URL = serviceUrl("order.service.url");
    private static final String INVENTORY_SERVICE_URL = serviceUrl("inventory.service.url");

    private final OkHttpClient client = new OkHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private static Properties loadServices() {
        Properties props = new Properties();
        Path file = Path.of("services.properties");
        if (Files.isRegularFile(file)) {
            try (InputStream in = Files.newInputStream(file)) {
                props.load(in);
            } catch (IOException e) {
                throw new IllegalStateException("Failed to load services.properties", e);
            }
        }
        return props;
    }

    private static String serviceUrl(String key) {
        String fromSys = System.getProperty(key);
        if (fromSys != null && !fromSys.isBlank()) {
            return fromSys;
        }
        String fromFile = SERVICES.getProperty(key);
        if (fromFile != null && !fromFile.isBlank()) {
            return fromFile;
        }
        throw new IllegalStateException("Missing service URL for " + key + " (set system property or services.properties)");
    }

    @Test(description = "A→B→C: order → inventory → shipping")
    public void combination_ABC_orderViaInventoryAndShipping() throws Exception {
        String requestBody = "{\"sku\":\"CG-ABC\",\"quantity\":2}";

        Request create = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        String orderId;
        try (Response response = client.newCall(create).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            JsonNode json = objectMapper.readTree(response.body().string());
            orderId = json.get("id").asText();
            assertThat(orderId).isNotEmpty();
            assertThat(json.get("status").asText()).isEqualTo("CONFIRMED");
            assertThat(json.get("estimatedDeliveryDays").asInt()).isGreaterThan(0);
        }

        Request get = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders/" + orderId)
            .build();

        try (Response response = client.newCall(get).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            JsonNode json = objectMapper.readTree(response.body().string());
            assertThat(json.get("id").asText()).isEqualTo(orderId);
            assertThat(json.get("sku").asText()).isEqualTo("CG-ABC");
        }
    }

    @Test(description = "A↔B: inventory stock-order → order (getEta)")
    public void combination_AB_inventoryStockOrderViaOrder() throws Exception {
        String url = INVENTORY_SERVICE_URL + "/stock-order/CG-AB";
        Request request = new Request.Builder().url(url).build();

        try (Response response = client.newCall(request).execute()) {
            String body = response.body() != null ? response.body().string() : "";
            assertThat(response.isSuccessful())
                .as("GET %s -> HTTP %s body=%s", url, response.code(), body)
                .isTrue();
            JsonNode json = objectMapper.readTree(body);
            assertThat(json.get("sku").asText()).isEqualTo("CG-AB");
            assertThat(json.get("quantity").asInt()).isGreaterThan(0);
            assertThat(json.get("etaDays").asInt()).isGreaterThan(0);
        }
    }
}
