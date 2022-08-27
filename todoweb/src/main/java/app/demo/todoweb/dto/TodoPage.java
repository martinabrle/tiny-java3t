package app.demo.todoweb.dto;

import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import app.demo.todoweb.utils.AppLogger;
import app.demo.todoweb.utils.Utils;

public class TodoPage {

    public static final AppLogger LOGGER = new AppLogger(TodoPage.class);

    private String todoText;

    private List<Todo> todoList;

    public TodoPage() {
        todoList = new ArrayList<Todo>();
    }

    public String getTodoText() {
        return todoText;
    }

    public void setTodoText(String text) {
        todoText = text;
    }

    public List<Todo> getTodoList() {
        return todoList;
    }

    public void setTodoList(List<Todo> todoList) {
        this.todoList = todoList;
    }

    @Override
    public String toString() {
        try {
            return new ObjectMapper().writeValueAsString(this);
        } catch (JsonProcessingException ex) {
            LOGGER.error(String.format("Failed to convert TodoPage into a string (%s)", ex.getMessage()), ex);
        }
        // This is just for the impossible case where the ObjectMapper throws an
        // exception
        return "{" +
                " 'todoText': '" + Utils.toJsonValueContent(todoText) + "', " +
                " 'todoList': " + todoList.toString() +
                '}';
    }
}