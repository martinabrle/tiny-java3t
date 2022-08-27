package app.demo.todoapi.utils;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.env.PropertySource;
import org.springframework.stereotype.Component;

@Component
public class AppEnvironmentListener implements EnvironmentPostProcessor {
    
    public static final AppLogger LOGGER = new AppLogger(AppEnvironmentListener.class);

    private static final boolean DEBUG_AUTH_TOKEN = getDebugAuthToken();

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        MutablePropertySources propertySources = environment.getPropertySources();
        retrieveReferencedKeyVaultSecrets(propertySources);
    }

    private void retrieveReferencedKeyVaultSecrets(MutablePropertySources propertySources) {
        LOGGER.debug("Parsing property sources....");

        Iterator<PropertySource<?>> it = propertySources.iterator();
        while (it.hasNext()) {
            MapPropertySource propertySource;
            try {
                propertySource = (MapPropertySource) it.next();
            } catch (Exception ignoreException) {
                propertySource = null;
            }

            if (propertySource == null) {
                LOGGER.debug(String.format("Skipping PropertySource as it is not of type '%s'",
                        MapPropertySource.class.getName()));
                continue;
            }

            var propertyNames = propertySource.getPropertyNames();
            if (propertyNames.length < 1) {
                LOGGER.debug(String.format(
                        "Skipping property source name '%s', type '%s', as the getNames() returned nothing.",
                        propertySource.getName(), propertySource.getClass().getName()));
                continue;
            }

            Map<String, Object> newProperties = new HashMap<String, Object>();
            boolean propertyTransformed = false;

            for (int i = 0; i < propertyNames.length; i++) {
                try {
                    String origPropertyValue = propertySource.getProperty(propertyNames[i]).toString();
                    String propertyValue = origPropertyValue;
                    if (propertyValue != null) {

                        String transformedPropertyValue = replaceEnvironmentVars(propertyValue);
                        if (!propertyValue.equals(transformedPropertyValue)) {
                            propertyTransformed = true;
                            LOGGER.debug(String.format("Property transformation 1: '%s': '%s' -> '%s'",
                                    propertyNames[i], origPropertyValue, transformedPropertyValue));
                            propertyValue = transformedPropertyValue;
                        }

                        if (transformedPropertyValue != null) {
                            String secondTransformedPropertyValue = replaceKeyVaultSecretReferences(
                                    transformedPropertyValue);

                            if (!transformedPropertyValue.equals(secondTransformedPropertyValue)) {
                                propertyTransformed = true;
                                LOGGER.debug(String.format("Property transformation 2: '%s': '%s' -> '%s'",
                                        propertyNames[i], transformedPropertyValue, secondTransformedPropertyValue));
                                propertyValue = secondTransformedPropertyValue;
                            }
                        }
                    }
                    newProperties.put(propertyNames[i], propertyValue);
                } catch (Exception ignoreException) {
                    LOGGER.error(String.format("Failed to retrieve a configuration property '%s' (%s)",
                            propertyNames[i], ignoreException.getMessage()), ignoreException);
                }
            }

            if (propertyTransformed) {
                var target = new MapPropertySource(propertySource.getName(), newProperties);
                propertySources.replace(propertySource.getName(), target);
                LOGGER.debug(String.format("Property source '%s' has been transformed", propertySource.getName()));
            }
        }
    }

    public static String replaceKeyVaultSecretReferences(String value) {
        String processedValue = value;

        if (processedValue.contains("@Microsoft.KeyVault(")) {

            var valueArray = processedValue.split("\\@Microsoft.KeyVault\\(");
            for (int j = 0; j < valueArray.length; j++) {
                int closingBracket = valueArray[j].indexOf(')');
                if (closingBracket > 0) {
                    try {
                        var localKVReference = valueArray[j].substring(0, closingBracket);

                        var trimmedLocalKVReference = localKVReference.trim();
                        String keyVaultName = trimmedLocalKVReference.substring(
                                trimmedLocalKVReference.indexOf("VaultName=") + "VaultName=".length(),
                                trimmedLocalKVReference.indexOf(";SecretName="));

                        if (!keyVaultName.isEmpty()) {

                            String keyVaultSecretName = trimmedLocalKVReference.substring(
                                    trimmedLocalKVReference.indexOf(";SecretName=") + ";SecretName=".length(),
                                    trimmedLocalKVReference.length());

                            if (!keyVaultSecretName.isEmpty()) {
                                String transformedPropertyValue = KeyVaultHelper.getSecret(keyVaultName,
                                        keyVaultSecretName, DEBUG_AUTH_TOKEN);

                                if (transformedPropertyValue != null) {
                                    processedValue = processedValue.replace(
                                            "@Microsoft.KeyVault(" + localKVReference + ")", transformedPropertyValue);
                                }
                            }
                        }
                    } catch (Exception ex) {
                        LOGGER.error(String.format("An error has occurred while replacing KeyVault references ('%s')",
                                ex.getMessage()), ex);
                    }
                }
            }
        }
        return processedValue;
    }

    private String replaceEnvironmentVars(String value) {
        String processedValue = value;

        if (processedValue.contains("${")) {
            try {
                var environmentVariableNames = processedValue.split("\\$\\{");
                for (String tmp : environmentVariableNames) {
                    int closingBracket = tmp.indexOf('}');
                    if (closingBracket > 0) {
                        String environmentVariableName = tmp.substring(0, tmp.indexOf('}'));

                        String trimmedEnvironmentVariableName = environmentVariableName.trim();
                        if (!trimmedEnvironmentVariableName.isEmpty()) {
                            var envValue = System.getenv(trimmedEnvironmentVariableName);
                            if (envValue != null) {
                                String localEnvVariableName = "${" + environmentVariableName + "}";
                                processedValue = processedValue.replace(localEnvVariableName, envValue);
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                LOGGER.error(String.format("Exception '%s' has occured", ex.getMessage()), ex);
            }
        }

        return processedValue;
    }

    private static boolean getDebugAuthToken() {
        boolean retVal;
        try {
            String debugAuthToken = System.getenv("DEBUG_AUTH_TOKEN");
            retVal = debugAuthToken != null && debugAuthToken.toLowerCase().compareTo("true") == 0;
        } catch (Exception ignoreException) {
            retVal = false;
        }
        return retVal;
    }
}