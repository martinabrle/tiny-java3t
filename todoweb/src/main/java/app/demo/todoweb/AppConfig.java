package app.demo.todoweb;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import app.demo.todoweb.utils.AppLogger;

@Configuration
@ConfigurationProperties(prefix = "app.demo.todoweb")
public class AppConfig {
    public static final AppLogger LOGGER = new AppLogger(AppConfig.class);

    private String applicationClientId;
    private String debugAuthToken;
    private String todoApiUri;

    public void setApplicationClientId(String applicationClientId) {
        this.applicationClientId = applicationClientId;
    }

    public void setDebugAuthToken(String debugAuthToken) {
        this.debugAuthToken = debugAuthToken;
    }

    public String getApplicationClientId() {
        return applicationClientId;
    }

    public boolean getDebugAuthToken() {
        return debugAuthToken != null && debugAuthToken.toLowerCase().trim().equals("true");
    }

    public String getTodoApiUri() {
        return todoApiUri;
    }

    public String getTodoApiUri(String path) {

        if (path == null) {
            return todoApiUri;
        }

        if (todoApiUri == null) {
            return path;
        }

        if (!todoApiUri.endsWith("/")) {
            if (path.startsWith("/")) {
                return todoApiUri + path;
            }
            return todoApiUri + "/" + path;
        }

        if (path.startsWith("/")) {
            return todoApiUri + path.substring(1);
        }
        return todoApiUri + path;
    }

    public String getApiVersionUri() {
        String apiUri = this.getTodoApiUri();
        if (apiUri.endsWith("/")) {
            apiUri = apiUri.substring(0, apiUri.length());
        }
        if (apiUri.endsWith("todos")) {
            apiUri = apiUri.substring(0, apiUri.length() - "todos".length());
        }
        apiUri += "/version";
        return apiUri;

    }

    public void setTodoApiUri(String todoApiUri) {
        this.todoApiUri = todoApiUri;
    }

    public String getVersion() {
        String version = "Unknown";
        try {
            version = this.getClass().getPackage().getImplementationVersion();
        } catch (Exception ignoreException) {
            LOGGER.error("An error has occurred while trying to retrieve the package version.");
        }
        return version;
    }

    public String getApiVersion() {
        String version = "Unknown";
        try {
            version = this.getClass().getPackage().getImplementationVersion();
        } catch (Exception ignoreException) {
            LOGGER.error("An error has occurred while trying to retrieve the package version.");
        }
        return version;
    }

    public String getEnvironment() {
        String environment = "Unknown";
        return environment;
    }

}