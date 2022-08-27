package app.demo.todoapi.service;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;

import app.demo.todoapi.dto.Todo;
import app.demo.todoapi.exception.NewTodoIsEmptyException;
import app.demo.todoapi.exception.TodoCreationFailedException;
import app.demo.todoapi.exception.TodoDeleteFailedException;
import app.demo.todoapi.exception.TodoIsEmptyException;
import app.demo.todoapi.exception.TodoNotFoundException;
import app.demo.todoapi.exception.TodoUpdateFailedException;
import app.demo.todoapi.exception.TodosRetrievalFailedException;

@Service
public interface TodoService {

    public List<Todo> getTodos() throws TodosRetrievalFailedException;
    public Todo getTodo(UUID id) throws TodoNotFoundException, TodosRetrievalFailedException;
    public Todo createTodo(String todoText) throws TodoCreationFailedException, NewTodoIsEmptyException;
    public Todo updateTodo(Todo todo) throws TodoIsEmptyException, TodoUpdateFailedException, TodoNotFoundException;
    public List<Todo> updateTodos(List<Todo> todos) throws TodoIsEmptyException, TodoUpdateFailedException, TodoNotFoundException;
    public void deleteTodo(UUID fromString) throws TodoNotFoundException, TodoDeleteFailedException;
}
