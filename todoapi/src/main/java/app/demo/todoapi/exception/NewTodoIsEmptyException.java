package app.demo.todoapi.exception;

public class NewTodoIsEmptyException extends RuntimeException {

    public NewTodoIsEmptyException() {
        super(String.format("Todo cannot be empty."));
    }
}