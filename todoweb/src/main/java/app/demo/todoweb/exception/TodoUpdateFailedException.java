package app.demo.todoweb.exception;

public class TodoUpdateFailedException extends RuntimeException{
    private String technicalDetail;

    public TodoUpdateFailedException(String technicalDetail) {
        super(String.format("Todos update failed"));
        this.technicalDetail = technicalDetail;
    }

    public String getTechnicalDetail() {
        return technicalDetail;
    }
}
