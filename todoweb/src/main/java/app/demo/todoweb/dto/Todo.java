package app.demo.todoweb.dto;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import app.demo.todoweb.utils.AppLogger;
import app.demo.todoweb.utils.Utils;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Objects;
import java.util.UUID;

public class Todo {
    
    public static final AppLogger LOGGER = new AppLogger(Todo.class);

    private UUID id;

    private String todoText;

    private Date createdDateTime;
    
    private Date completedDateTime;

    boolean completed;
    boolean completedOrig;

    public Todo() {
        
    }

    public Todo(UUID id, String todoText, Date createdDateTime, Date completedDateTime, boolean completed) {
        this.id = id;
        this.completedDateTime = completedDateTime;
        this.createdDateTime = createdDateTime;
        this.todoText = todoText;
        this.completed = completed;
        this.completedOrig = completed;

    }

    public Todo(app.demo.todoweb.entity.Todo todo) {
        initFromTodo(todo);
    }
    
    public void initFromTodo(app.demo.todoweb.entity.Todo todo) {
        this.id = todo.getId();
        this.createdDateTime = todo.getCreatedDateTime();
        this.completedDateTime = todo.getCompletedDateTime();
        this.todoText = todo.getTodoText();
        this.completed = this.completedDateTime != null;
        this.completedOrig = this.completed;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        Todo todo = (Todo) o;
        return Objects.equals(id, todo.id) &&
                ((createdDateTime == null && todo.createdDateTime == null)
                        || (createdDateTime != null && createdDateTime.compareTo(todo.createdDateTime) == 0))
                &&
                Objects.equals(todoText, todo.todoText) &&
                ((completedDateTime == null && todo.completedDateTime == null)
                        || (completedDateTime != null && completedDateTime.compareTo(todo.completedDateTime) == 0));
    }

    @Override
    public int hashCode() {

        return Objects.hash(id, createdDateTime, todoText, completedDateTime);
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getTodoText() {
        return todoText;
    }

    public void setTodoText(String todoText) {
        this.todoText = todoText;
    }

    public Date getCreatedDateTime() {
        return createdDateTime;
    }

    public void setCreatedDateTime(Date createdDateTime) {
        this.createdDateTime = createdDateTime;
    }

    public Date getCompletedDateTime() {
        return completedDateTime;
    }

    public void setCompletedDateTime(Date completedDateTime) {
        this.completedDateTime = completedDateTime;
    }

    public boolean getCompleted() {
        return completed;
    }

    public void setCompleted(Boolean completed) {
        this.completed = completed;
    }

    public boolean getCompletedOrig() {
        return completedOrig;
    }

    public void setCompletedOrig(Boolean completedOrig) {
        this.completedOrig = completedOrig;
    }

    public String getStatus() {
        return (completedDateTime != null ? "Completed" : "Pending");
    }

    public String getStatusText() {
        if (createdDateTime == null) {
            return "";
        }

        SimpleDateFormat sdf = new SimpleDateFormat("dd.MM.YYYY");

        if (completedDateTime != null) {
            return "created: " + sdf.format(createdDateTime) + ", completed: " + sdf.format(completedDateTime);
        }
        return "created: " + sdf.format(createdDateTime);
    }

    @Override
    public String toString() {
        try {
            return new ObjectMapper().writeValueAsString(this);
        } catch (JsonProcessingException ex) {
            LOGGER.error(String.format("Failed to convert Todo into a string (%s)", ex.getMessage()), ex);
        }
        // This is just for the impossible case where the ObjectMapper throws an
        // exception
        return "{" +
                "'id':" + id +
                ", 'todoText':'" + Utils.toJsonValueContent(todoText) + "'" +
                ", 'createdDateTime':'" + Utils.toJsonValueContent(createdDateTime) + "'" +
                ", 'completedDateTime':'" + Utils.toJsonValueContent(completedDateTime) + "'" +
                ", 'completed':" + completed + "" +
                "}";
    }
}