package app.demo.todoapi.exception;

public class TodoIdCannotBeEmptyException extends RuntimeException{
    private String technicalDetail;

    public TodoIdCannotBeEmptyException(String technicalDetail) {
        super(String.format("Todo Id can not be empty"));
        this.technicalDetail = technicalDetail;
    }

    public String getTechnicalDetail() {
        return technicalDetail;
    }
}
