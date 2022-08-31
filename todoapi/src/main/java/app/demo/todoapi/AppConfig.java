package app.demo.todoapi;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import com.azure.identity.AzureCliCredential;
import com.azure.identity.AzureCliCredentialBuilder;
import com.azure.identity.ManagedIdentityCredential;
import com.azure.identity.ManagedIdentityCredentialBuilder;

import app.demo.todoapi.utils.AppLogger;

@Configuration
@ConfigurationProperties(prefix = "app.demo.todoapi")
public class AppConfig {
    public static final AppLogger LOGGER = new AppLogger(AppConfig.class);

    private String applicationClientId;
    private String loadDemoData;
    private String debugAuthToken;

    // Token identity for AAD integration while running on local machine
    @Bean
    @Profile("local-mi")
    public AzureCliCredential azureCliCredential() {
        return new AzureCliCredentialBuilder().build();
    }

    // Token identity for AAD integration while running in Azure
    @Bean
    @Profile({ "test-mi", "prod-mi" })
    public ManagedIdentityCredential managedIdentityCredentialTest() {

        LOGGER.debug(String.format("Connecting to the database using Application ClientID '%s'", applicationClientId));
        return new ManagedIdentityCredentialBuilder()
                .clientId(applicationClientId)
                .build();
    }

    public void setApplicationClientId(String applicationClientId) {
        this.applicationClientId = applicationClientId;
    }

    public void setLoadDemoData(String loadDemoData) {
        this.loadDemoData = loadDemoData;
    }

    public void setDebugAuthToken(String debugAuthToken) {
        this.debugAuthToken = debugAuthToken;
    }

    public String getApplicationClientId() {
        return applicationClientId;
    }

    public boolean getLoadDemoData() {
        return loadDemoData != null && loadDemoData.toLowerCase().trim().equals("true");
    }

    public boolean getDebugAuthToken() {
        return debugAuthToken != null && debugAuthToken.toLowerCase().trim().equals("true");
    }
}