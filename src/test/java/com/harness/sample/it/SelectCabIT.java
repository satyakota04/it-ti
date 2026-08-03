package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import okhttp3.Request;
import okhttp3.Response;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** C→A→B: shipping ship-order → order lookup → inventory qty.. */
public class SelectCabIT extends ItSupport {

    @Test(description = "C→A→B: shipping ship-order → order lookup → inventory qty")
    public void combination_CAB_shippingShipOrderViaOrder() throws Exception {
        String url = shippingServiceUrl() + "/ship-order/CG-CAB";
        Request request = new Request.Builder().url(url).build();

        try (Response response = client.newCall(request).execute()) {
            String body = response.body() != null ? response.body().string() : "";
            assertThat(response.isSuccessful())
                .as("GET %s -> HTTP %s body=%s", url, response.code(), body)
                .isTrue();
            JsonNode json = objectMapper.readTree(body);
            assertThat(json.get("sku").asText()).isEqualTo("CG-CAB");
            assertThat(json.get("quantity").asInt()).isGreaterThan(0);
            assertThat(json.get("etaDays").asInt()).isGreaterThan(0);
        }
    }
}
