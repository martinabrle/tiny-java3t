package app.demo.todoweb.service;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;

import app.demo.todoweb.dto.Todo;
import app.demo.todoweb.exception.NewTodoIsEmptyException;
import app.demo.todoweb.exception.TodoCreationFailedException;
import app.demo.todoweb.exception.TodoDeleteFailedException;
import app.demo.todoweb.exception.TodoIsEmptyException;
import app.demo.todoweb.exception.TodoNotFoundException;
import app.demo.todoweb.exception.TodoUpdateFailedException;
import app.demo.todoweb.exception.TodosRetrievalFailedException;

@Service
public interface TodoService {

    public List<Todo> getTodos() throws TodosRetrievalFailedException;
    public Todo getTodo(UUID id) throws TodoNotFoundException, TodosRetrievalFailedException;
    public Todo createTodo(String todoText) throws TodoCreationFailedException, NewTodoIsEmptyException;
    public Todo updateTodo(Todo todo) throws TodoIsEmptyException, TodoUpdateFailedException, TodoNotFoundException;
    public List<Todo> updateTodos(List<Todo> todos) throws TodoIsEmptyException, TodoUpdateFailedException, TodoNotFoundException;
    public void deleteTodo(UUID fromString) throws TodoNotFoundException, TodoDeleteFailedException;
}
