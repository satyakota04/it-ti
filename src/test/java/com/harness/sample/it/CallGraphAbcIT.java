package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** A→B→C: order → inventory → shipping. */
public class CallGraphAbcIT extends ItSupport {

    @Test(description = "A→B→C: order → inventory → shipping")
    public void combination_ABC_orderViaInventoryAndShipping() throws Exception {
        String requestBody = "{\"sku\":\"CG-ABC\",\"quantity\":2}";

        Request create = new Request.Builder()
            .url(orderServiceUrl() + "/orders")
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
            .url(orderServiceUrl() + "/orders/" + orderId)
            .build();

        try (Response response = client.newCall(get).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            JsonNode json = objectMapper.readTree(response.body().string());
            assertThat(json.get("id").asText()).isEqualTo(orderId);
            assertThat(json.get("sku").asText()).isEqualTo("CG-ABC");
        }
    }
}
