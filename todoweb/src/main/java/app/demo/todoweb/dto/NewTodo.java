package app.demo.todoweb.dto;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import app.demo.todoweb.utils.AppLogger;
import app.demo.todoweb.utils.Utils;

public class NewTodo {

    public static final AppLogger LOGGER = new AppLogger(NewTodo.class);

    private String todoText;

    public NewTodo(String todoText) {
        this.todoText = todoText;
    }

    public NewTodo() {
    }

    public String getTodoText() {
        return todoText;
    }

    public void setTodoText(String text) {
        todoText = text;
    }

    @Override
    public String toString() {
        try {
            return new ObjectMapper().writeValueAsString(this);
        } catch (JsonProcessingException ex) {
            LOGGER.error(String.format("Failed to convert NewTodo into a string: (%s)", ex.getMessage()), ex);
        }
        // This is just for the impossible case where the ObjectMapper throws an
        // exception
        return "{" +
                " 'todoText':'" + Utils.toJsonValueContent(todoText) + "' " +
                "}";
    }
}