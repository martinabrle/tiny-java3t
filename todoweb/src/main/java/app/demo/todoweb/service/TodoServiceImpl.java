package app.demo.todoweb.service;

import java.util.ArrayList;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import app.demo.todoweb.dto.NewTodo;
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

        LOGGER.debug(String.format("Retrieved all TODOs synchronously using getTodos(), no of TODOs: %s", retVal.size()));

        return retVal;
    }

    public Todo getTodo(UUID id)
            throws TodoNotFoundException, TodosRetrievalFailedException {

        Todo retVal = null;

        LOGGER.debug(String.format("Retrieving a TODO synchronously using getTodo('%s')", id));

        try {
            var retrievedTodoEntity = repository.findById(id);

            if (retrievedTodoEntity == null) {
                throw new TodoNotFoundException(
                        String.format("Unable to retrieve Todo '%s'; Todo does not exist (1).", id));
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

            var newTodoEntoty = new NewTodo(todoText);
            
            var todoEntitySaved = repository.insert(newTodoEntoty);

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

            var existingTodo = repository.findById(todo.getId());

            if (existingTodo == null || existingTodo.getId() == null)
                throw new TodoNotFoundException(String.format("Todo '%s' does not exist.", todo.getId()));

            existingTodo.setTodoText(todo.getTodoText());
            existingTodo.setCompletedDateTime(todo.getCompletedDateTime());

            var savedTodoEntity = repository.update(existingTodo);

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
            throws TodoUpdateFailedException, TodoNotFoundException {

        List<Todo> retVal;

        LOGGER.debug(String.format("Updating TODOs synchronously using updateTodos (length: '%s')", todos.size()));

        try {
            retVal = repository.updateAll(todos);
        }
        catch (TodoUpdateFailedException ex) {
            LOGGER.debug(String.format("An error occurred while updating one or more TODOs: %s ", ex.getMessage()), ex);
            throw ex;
        }
        catch (TodoNotFoundException ex) {
            LOGGER.debug(String.format("An error occurred while updating one or more TODOs; one or more TODOs on the list do not exist: %s", ex.getMessage()), ex);
            throw ex;
        }
        catch (Exception ex) {
            LOGGER.debug(String.format("An error occurred while updating one or more TODOs (generic): %s", ex.getMessage()), ex);
            throw new TodoUpdateFailedException(ex.getMessage());
        }
        return retVal;
    }

    @Override
    public String getApiVersion() {
        LOGGER.debug(String.format("Retrieving API version synchronously using getApiVersion()"));

        String retVal = "unknown";

        try {
            retVal = repository.getApiVersion();
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving API version failed (%s)", ex.getMessage()), ex);
            retVal = "unknown";
        }
        if (retVal == null) {
            retVal = "unknown";
        }
        LOGGER.debug(String.format("Retrievend an API version synchronously using getApiVersion(): %s", retVal));
        return retVal;
    }
}
