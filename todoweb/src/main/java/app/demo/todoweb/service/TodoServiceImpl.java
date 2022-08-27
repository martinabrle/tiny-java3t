package app.demo.todoweb.service;

import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import app.demo.todoweb.dto.Todo;
import app.demo.todoweb.exception.NewTodoIsEmptyException;
import app.demo.todoweb.exception.TodoCreationFailedException;
import app.demo.todoweb.exception.TodoDeleteFailedException;
import app.demo.todoweb.exception.TodoIdCannotBeEmptyException;
import app.demo.todoweb.exception.TodoIsEmptyException;
import app.demo.todoweb.exception.TodoNotFoundException;
import app.demo.todoweb.exception.TodoUpdateFailedException;
import app.demo.todoweb.exception.TodosRetrievalFailedException;
import app.demo.todoweb.repository.TodoRepository;
import app.demo.todoweb.utils.AppLogger;

@Service
public class TodoServiceImpl implements TodoService {

    @Autowired
    private TodoRepository repository;

    public static final AppLogger LOGGER = new AppLogger(TodoServiceImpl.class);

    public List<Todo> getTodos() throws TodosRetrievalFailedException {

        List<Todo> retVal = null;

        LOGGER.debug("Retrieving all TODOs synchronously using getTodos()");

        try {
            var todoEntityList = repository.findAll(Sort.by(Sort.Direction.DESC, "createdDateTime"));

            retVal = new ArrayList<Todo>();
            for (var e : todoEntityList) {
                retVal.add(new Todo(e.getId(), e.getTodoText(), e.getCreatedDateTime(), e.getCompletedDateTime(),
                        e.getCompletedDateTime() != null));
            }
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving all TODOs failed (%s)", ex.getMessage()), ex);
            throw new TodosRetrievalFailedException(ex.getMessage());
        }

        LOGGER.debug("Retrieved all TODOs synchronously using getTodos()");

        return retVal;
    }

    public Todo getTodo(UUID id)
            throws TodoNotFoundException, TodosRetrievalFailedException {

        Todo retVal = null;

        LOGGER.debug(String.format("Retrieving a TODO synchronously using getTodo('%s')", id));

        try {
            var retrievedOptionalTodoEntity = repository.findById(id);

            if (!retrievedOptionalTodoEntity.isPresent()) {
                throw new TodoNotFoundException(
                        String.format("Unable to retrieve Todo '%s'; Todo does not exist (1).", id));
            }

            var retrievedTodoEntity = retrievedOptionalTodoEntity.get();

            if (retrievedTodoEntity == null) {
                throw new TodoNotFoundException(String.format("Unable to retrieve Todo '%s' (2).", id));
            }

            retVal = new Todo(retrievedTodoEntity.getId(), retrievedTodoEntity.getTodoText(),
                    retrievedTodoEntity.getCreatedDateTime(), retrievedTodoEntity.getCompletedDateTime(),
                    retrievedTodoEntity.getCompletedDateTime() != null);
            
        } catch (TodoNotFoundException ex) {
            throw ex;
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving the TODO '%s' failed (%s)", id, ex.getMessage()), ex);
            throw new TodosRetrievalFailedException(ex.getMessage());
        }
        
        LOGGER.debug(String.format("Retrieved a TODO synchronously using getTodo('%s')", id));

        return retVal;
    }

    public Todo createTodo(String todoText)
            throws TodoCreationFailedException, NewTodoIsEmptyException {

        Todo todo = null;

        if (todoText == null || todoText.trim() == "") {
            throw new NewTodoIsEmptyException();
        }

        try {
            LOGGER.debug(String.format("Create a new Todo synchronously using createTodo('%s')", todoText));

            var todoEntity = new app.demo.todoweb.entity.Todo(UUID.randomUUID(), todoText, new Date(), null);

            var todoEntitySaved = repository.save(todoEntity);

            todo = new Todo(todoEntitySaved.getId(), todoEntitySaved.getTodoText(),
                    todoEntitySaved.getCreatedDateTime(), todoEntitySaved.getCompletedDateTime(),
                    todoEntitySaved.getCompletedDateTime() != null);

            LOGGER.debug(String.format("Created a new Todo with Id '%s'", todo.getId()));
        } catch (NewTodoIsEmptyException ex) {
            throw ex;
        } catch (Exception ex) {
            LOGGER.error(String.format("Todo creation failed (%s)", ex.getMessage()), ex);
            throw new TodoCreationFailedException(ex.getMessage());
        }
        return todo;
    }

    public Todo updateTodo(Todo todo)
            throws TodoIsEmptyException, TodoUpdateFailedException, TodoNotFoundException {

        Todo retVal = null;
        if (todo == null || todo.getTodoText().isBlank())
            throw new TodoIsEmptyException(todo.getId(), null);

        try {
            LOGGER.debug(String.format("Updating an existing Todo '%s' synchronously using updateTodo(..)", todo.getId()));

            var existingTodoEntityLookup = repository.findById(todo.getId());

            if (!existingTodoEntityLookup.isPresent())
                throw new TodoNotFoundException(String.format("Todo '%s' does not exist.", todo.getId()));

            var existingTodoEntity = existingTodoEntityLookup.get();
            existingTodoEntity.setTodoText(todo.getTodoText());
            existingTodoEntity.setCompletedDateTime(todo.getCompletedDateTime());

            var savedTodoEntity = repository.save(existingTodoEntity);

            retVal = new Todo(savedTodoEntity.getId(), savedTodoEntity.getTodoText(),
                    savedTodoEntity.getCreatedDateTime(), savedTodoEntity.getCompletedDateTime(),
                    savedTodoEntity.getCompletedDateTime() != null);
        } catch (NoSuchElementException ex) {
            throw new TodoNotFoundException(String.format("Todo '%s' does not exist.", todo.getId()));
        } catch (TodoIsEmptyException ex) {
            throw ex;
        } catch (TodoNotFoundException ex) {
            throw ex;
        } catch (Exception ex) {
            LOGGER.error(String.format("Todo update failed (%s)", ex.getMessage()), ex);
            throw new TodoUpdateFailedException(ex.getMessage());
        }

        LOGGER.debug(String.format("Updated an existing Todo '%s' synchronously using updateTodo(..)", todo.getId()));

        return retVal;
    }

    @Override
    public void deleteTodo(UUID id)
            throws TodoNotFoundException, TodoDeleteFailedException, TodoIdCannotBeEmptyException {

        LOGGER.debug(String.format("Deleting a TODO synchronously using deleteTodo('%s')", id));

        try {
            if (!repository.existsById(id)) {
                throw new TodoNotFoundException("Unable to retrieve the Todo; Todo does not exist (1).");
            }

            repository.deleteById(id);

        } catch (IllegalArgumentException ex) {
            LOGGER.error(String.format("Retrieving the TODO '%s' failed (%s)", id, ex.getMessage()), ex);
            throw new TodoIdCannotBeEmptyException(ex.getMessage());
        } catch (TodoNotFoundException ex) {
            throw ex;
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving the TODO '%s' failed (%s)", id, ex.getMessage()), ex);
            throw new TodosRetrievalFailedException(ex.getMessage());
        }
        LOGGER.debug(String.format("Deleted a TODO synchronously using deleteTodo('%s')", id));
    }

    @Override
    public List<Todo> updateTodos(List<Todo> todos)
            throws TodoIsEmptyException, TodoUpdateFailedException, TodoNotFoundException {

        var todoListHashMap = new HashMap<UUID, Todo>();
        var todoEntities = new ArrayList<app.demo.todoweb.entity.Todo>();

        for (var todo : todos) {
            todoListHashMap.put(todo.getId(), todo);
        }

        var retrievedTodoEntities = repository.findAllById(todoListHashMap.keySet());
        for (var retrievedTodoEntity : retrievedTodoEntities) {
            var updatedTodo = todoListHashMap.get(retrievedTodoEntity.getId());
            boolean valuesModified = false;
            if (updatedTodo.getCompleted() && retrievedTodoEntity.getCompletedDateTime() == null) {
                retrievedTodoEntity.setCompletedDateTime(new Date());
                valuesModified = true;
            } else if (!updatedTodo.getCompleted() && retrievedTodoEntity.getCompletedDateTime() != null) {
                retrievedTodoEntity.setCompletedDateTime(null);
                valuesModified = true;
            } else if (retrievedTodoEntity.getCompletedDateTime() != updatedTodo.getCompletedDateTime()) {
                retrievedTodoEntity.setCompletedDateTime(updatedTodo.getCompletedDateTime());
                valuesModified = true;
            }
            if (updatedTodo.getTodoText() != null) {
                if (updatedTodo.getTodoText().isBlank()) {
                    throw new TodoIsEmptyException(updatedTodo.getId(), null);
                }
                if (!retrievedTodoEntity.getTodoText().equals(updatedTodo.getTodoText())) {
                    retrievedTodoEntity.setTodoText(updatedTodo.getTodoText());
                    valuesModified = true;
                }
            }
            if (valuesModified) {
                todoEntities.add(retrievedTodoEntity);
            }
        }

        var resultingTodoEntities = repository.saveAll(todoEntities);

        var retVal = new ArrayList<Todo>();
        for (var resultingTodoEntity : resultingTodoEntities) {
            retVal.add(new Todo(resultingTodoEntity.getId(), resultingTodoEntity.getTodoText(),
                    resultingTodoEntity.getCreatedDateTime(), resultingTodoEntity.getCompletedDateTime(),
                    resultingTodoEntity.getCompletedDateTime() != null));
        }

        return retVal;
    }

}
