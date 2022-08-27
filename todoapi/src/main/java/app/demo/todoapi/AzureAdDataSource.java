package app.demo.todoapi;

import com.azure.core.credential.SimpleTokenCache;
import com.azure.core.credential.TokenCredential;
import com.azure.core.credential.TokenRequestContext;
import com.zaxxer.hikari.HikariDataSource;

import app.demo.todoapi.utils.AppLogger;
import app.demo.todoapi.utils.FileCache;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

//https://www.azureblue.io/how-to-authenicated-aad-identity-against-postgres-using-spring-boot/
@Component
@ConfigurationProperties(prefix = "spring.datasource")
@Profile({ "local-mi", "test-mi", "prod-mi" })
public class AzureAdDataSource extends HikariDataSource {

    public static final AppLogger LOGGER = new AppLogger(AzureAdDataSource.class);

    @Autowired
    private AppConfig appConfig;

    public static final String BALTIMORE_CYBER_TRUST_ROOT = new FileCache()
            .cacheEmbededFile("BaltimoreCyberTrustRoot.crt.pem");
    public static final String DIGICERT_GLOBAL_ROOT = new FileCache().cacheEmbededFile("DigiCertGlobalRootCA.crt.pem");

    private final SimpleTokenCache cache;

    public AzureAdDataSource(TokenCredential credential) {
        this.cache = new SimpleTokenCache(() -> credential.getToken(createRequestContext()));
    }

    @Override
    public String getPassword() {
        var accessToken = cache
                .getToken()
                .retry(1L)
                .blockOptional()
                .orElseThrow(() -> new RuntimeException("Attempt to retrieve AAD token failed"));

        var token = accessToken.getToken();
        if (debugAuthToken()) {
            LOGGER.debug(String.format("Retrieved token for connecting to the datasource: '%s',", token.toString()));
        }

        return token;
    }

    private static TokenRequestContext createRequestContext() {
        return new TokenRequestContext().addScopes("https://ossrdbms-aad.database.windows.net/.default");
    }

    private boolean debugAuthToken() {
        return appConfig != null && appConfig.getDebugAuthToken();
    }
}
