package app.demo.todoweb.exception;

public class TodoNotFoundException extends RuntimeException {

    public TodoNotFoundException(String message) {
        super(String.format(message));
    }
}