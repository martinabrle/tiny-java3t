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

        if (!todoApiUri.endsWith("/"))
        {
            if (path.startsWith("/"))
            {
                return todoApiUri + path;
            }
            return todoApiUri + "/" + path;
        }

        if (path.startsWith("/")) {
            return todoApiUri + path.substring(1);
        }
        return todoApiUri + path;
    }

    public void setTodoApiUri(String todoApiUri) {
        this.todoApiUri = todoApiUri;
    }
}