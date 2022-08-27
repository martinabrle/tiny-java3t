package app.demo.todoweb.utils;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;

public class Token {
    public static final AppLogger LOGGER = new AppLogger(Token.class);

    @JsonProperty("access_token")
    private String accessToken;

    @JsonProperty("refresh_token")
    private String refreshToken;

    @JsonProperty("expires_in")
    private String expiresIn;

    @JsonProperty("expires_on")
    private String expiresOn;

    @JsonProperty("not_before")
    private String notBefore;

    @JsonProperty("resource")
    private String resource;

    @JsonProperty("token_type")
    private String tokenType;

    @JsonIgnore
    private Long expiresOnEpochTimeMS;

    public String getAccessToken() {
        return accessToken;
    }

    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

    public void setRefreshToken(String refreshToken) {
        this.refreshToken = refreshToken;
    }

    public String getExpiresIn() {
        return expiresIn;
    }

    public void setExpiresIn(String expiresIn) {
        this.expiresIn = expiresIn;
    }

    public String getExpiresOn() {
        return expiresOn;
    }

    public void setExpiresOn(String expiresOn) {
        this.expiresOn = expiresOn;
        try {
            this.expiresOnEpochTimeMS = Long.parseLong(expiresOn) * 1000;
        } catch (Exception ignoreException) {
            LOGGER.error(String.format("Weird exception while converting '%s' to epoch time (%s)", expiresOn, ignoreException.getMessage()), ignoreException);
            ignoreException.printStackTrace();
        }
    }

    public String getNotBefore() {
        return notBefore;
    }

    public void setNotBefore(String notBefore) {
        this.notBefore = notBefore;
    }

    public String getResource() {
        return resource;
    }

    public void setResource(String resource) {
        this.resource = resource;
    }

    public String getTokenType() {
        return tokenType;
    }

    public void setTokenType(String tokenType) {
        this.tokenType = tokenType;
    }

    public boolean isExpired() {
        if (this.expiresOnEpochTimeMS < (System.currentTimeMillis() + 200))
        {
            return true;
        }
        return false;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((accessToken == null) ? 0 : accessToken.hashCode());
        result = prime * result + ((expiresIn == null) ? 0 : expiresIn.hashCode());
        result = prime * result + ((expiresOn == null) ? 0 : expiresOn.hashCode());
        result = prime * result + ((notBefore == null) ? 0 : notBefore.hashCode());
        result = prime * result + ((refreshToken == null) ? 0 : refreshToken.hashCode());
        result = prime * result + ((resource == null) ? 0 : resource.hashCode());
        result = prime * result + ((tokenType == null) ? 0 : tokenType.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        Token other = (Token) obj;
        if (accessToken == null) {
            if (other.accessToken != null)
                return false;
        } else if (!accessToken.equals(other.accessToken))
            return false;
        if (expiresIn == null) {
            if (other.expiresIn != null)
                return false;
        } else if (!expiresIn.equals(other.expiresIn))
            return false;
        if (expiresOn == null) {
            if (other.expiresOn != null)
                return false;
        } else if (!expiresOn.equals(other.expiresOn))
            return false;
        if (notBefore == null) {
            if (other.notBefore != null)
                return false;
        } else if (!notBefore.equals(other.notBefore))
            return false;
        if (refreshToken == null) {
            if (other.refreshToken != null)
                return false;
        } else if (!refreshToken.equals(other.refreshToken))
            return false;
        if (resource == null) {
            if (other.resource != null)
                return false;
        } else if (!resource.equals(other.resource))
            return false;
        if (tokenType == null) {
            if (other.tokenType != null)
                return false;
        } else if (!tokenType.equals(other.tokenType))
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "Token [accessToken=" + accessToken + ", expiresIn=" + expiresIn + ", expiresOn=" + expiresOn
                + ", notBefore=" + notBefore + ", refreshToken=" + refreshToken + ", resource=" + resource
                + ", tokenType=" + tokenType + "]";
    }
}

// "access_token":"","refresh_token":"","expires_in":"68114","expires_on":"1660901900","not_before":"1660833725","resource":"https://vault.azure.net","token_type":"Bearer"
