package app.demo.todoweb.exception;

public class TodoCreationFailedException extends RuntimeException{
    private String technicalDetail;

    public TodoCreationFailedException(String technicalDetail) {
        super(String.format("Todos creation failed"));
        this.technicalDetail = technicalDetail;
    }

    public String getTechnicalDetail() {
        return technicalDetail;
    }
}
