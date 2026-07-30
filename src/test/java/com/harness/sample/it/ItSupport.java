package com.harness.sample.it;

import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.OkHttpClient;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

/** Shared HTTP client and service URL loading for IT classes. */
abstract class ItSupport {
    private static final Properties SERVICES = loadServices();

    protected final OkHttpClient client = new OkHttpClient();
    protected final ObjectMapper objectMapper = new ObjectMapper();

    protected static String orderServiceUrl() {
        return serviceUrl("order.service.url");
    }

    protected static String inventoryServiceUrl() {
        return serviceUrl("inventory.service.url");
    }

    protected static String shippingServiceUrl() {
        return serviceUrl("shipping.service.url");
    }

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
        throw new IllegalStateException(
            "Missing service URL for " + key + " (set system property or services.properties)");
    }
}
