package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import okhttp3.Request;
import okhttp3.Response;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** B→A→C: inventory stock-order → order eta → shipping priority-eta.. */
public class SelectBacIT extends ItSupport {

    @Test(description = "B→A→C: inventory stock-order → order eta → shipping priority-eta")
    public void combination_BAC_inventoryStockOrderViaOrder() throws Exception {
        String url = inventoryServiceUrl() + "/stock-order/CG-BAC";
        Request request = new Request.Builder().url(url).build();

        try (Response response = client.newCall(request).execute()) {
            String body = response.body() != null ? response.body().string() : "";
            assertThat(response.isSuccessful())
                .as("GET %s -> HTTP %s body=%s", url, response.code(), body)
                .isTrue();
            JsonNode json = objectMapper.readTree(body);
            assertThat(json.get("sku").asText()).isEqualTo("CG-BAC");
            assertThat(json.get("quantity").asInt()).isGreaterThan(0);
            assertThat(json.get("etaDays").asInt()).isGreaterThan(0);
        }
    }
}
