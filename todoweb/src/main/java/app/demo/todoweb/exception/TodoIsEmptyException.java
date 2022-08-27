package app.demo.todoweb.exception;

import java.util.UUID;

public class TodoIsEmptyException extends RuntimeException{
    private UUID id;
    private String technicalDetail;

    public TodoIsEmptyException(UUID id, String technicalDetail) {
        super(String.format("Todo delete failed"));
        this.technicalDetail = technicalDetail;
    }

    public UUID getId() {
        return id;
    }
    
    public String getTechnicalDetail() {
        return technicalDetail;
    }
}
