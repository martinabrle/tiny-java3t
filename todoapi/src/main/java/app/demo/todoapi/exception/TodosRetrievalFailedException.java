package app.demo.todoapi.exception;

public class TodosRetrievalFailedException extends RuntimeException{
    private String technicalDetail;

    public TodosRetrievalFailedException(String technicalDetail) {
        super(String.format("Todos retrieval failed"));
        this.technicalDetail = technicalDetail;
    }

    public String getTechnicalDetail() {
        return technicalDetail;
    }
}
