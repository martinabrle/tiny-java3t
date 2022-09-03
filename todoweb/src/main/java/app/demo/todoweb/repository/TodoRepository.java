package app.demo.todoweb.repository;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Repository;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import app.demo.todoweb.AppConfig;
import app.demo.todoweb.dto.NewTodo;
import app.demo.todoweb.dto.Todo;
import app.demo.todoweb.exception.TodoCreationFailedException;
import app.demo.todoweb.exception.TodoDeleteFailedException;
import app.demo.todoweb.exception.TodoNotFoundException;
import app.demo.todoweb.exception.TodoUpdateFailedException;
import app.demo.todoweb.exception.TodosRetrievalFailedException;
import app.demo.todoweb.utils.AppLogger;

import reactor.core.publisher.Mono;

@Repository
public class TodoRepository {

    public static final AppLogger LOGGER = new AppLogger(TodoRepository.class);
    @Autowired
    private AppConfig appConfig;

    public List<Todo> findAll(Sort by) throws TodosRetrievalFailedException {

        TodoList retValList = new TodoList();

        LOGGER.debug(String.format("Retrieving all TODOs synchronously using findAll(%s)", by)); // sort direction is
                                                                                                 // ignored

        try {

            String apiUri = appConfig.getTodoApiUri();
            WebClient webClient = WebClient.create(apiUri);

            retValList = webClient.get()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .retrieve()
                    .bodyToMono(TodoList.class)
                    .block();

            LOGGER.debug(String.format("Received back a list of TODOs (size %s) as a response:", retValList.size()),
                    retValList);
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving all TODOs failed: '%s'", ex.getMessage()), ex);
            throw new TodosRetrievalFailedException(ex.getMessage());
        }

        return retValList;
    }

    public Todo findById(UUID id) throws TodoNotFoundException, TodosRetrievalFailedException, Exception {

        Todo retVal = null;

        LOGGER.debug(String.format("Retrieving a TODO synchronously using findById(%s)", id));

        try {

            String apiUri = appConfig.getTodoApiUri("/" + id.toString());

            WebClient webClient = WebClient.create(apiUri);

            var findByIdResponse = webClient.get()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .retrieve()
                    .toEntity(Todo.class)
                    .block();

            if (findByIdResponse.getStatusCode() == HttpStatus.NOT_FOUND) {
                LOGGER.error(String.format("Todo findById(%s) API returned a http status %s ('%s') ", id,
                        findByIdResponse.getStatusCode().name(),
                        Integer.toString(findByIdResponse.getStatusCodeValue())));
                throw new TodoNotFoundException(String.format("Todo '%s' does not exist", id));
            }

            retVal = findByIdResponse.getBody();
            if (retVal == null)
                throw new TodoNotFoundException("Unable to retrieve the Todo or Todo does not exist.");

            LOGGER.debug("Received back this TODO structure as a response...", retVal);
        } catch (WebClientResponseException ex) {
            if (ex.getStatusCode() == HttpStatus.NOT_FOUND) {
                throw new TodoNotFoundException("Todo not found.");
            }
            if (ex.getStatusCode() == HttpStatus.BAD_REQUEST) {
                throw new TodosRetrievalFailedException(ex.getMessage());

            }
            throw new Exception(String.format("Server returned '%s'", ex.getStatusText()));
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving the TODO '%s' failed: %s", id, ex.getMessage()), ex);
            throw new TodosRetrievalFailedException(ex.getMessage());
        }

        return retVal;
    }

    public Todo insert(NewTodo newTodo) throws TodoCreationFailedException {
        Todo createdTodo = null;
        try {
            LOGGER.debug("Create a new Todo synchronously using insert: ", newTodo);

            String apiUri = appConfig.getTodoApiUri();
            WebClient webClient = WebClient.create(apiUri);

            var todo = new RepositoryTodo(UUID.randomUUID(), newTodo.getTodoText(), null, null);

            LOGGER.debug("Sending a POST request with a new TODO: ", todo);

            createdTodo = webClient.post()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .body(Mono.just(todo), Todo.class)
                    .retrieve()
                    .bodyToMono(Todo.class)
                    .block();

            LOGGER.debug("Received back a new TODO as a response:", createdTodo);
        } catch (Exception ex) {
            LOGGER.error(String.format("Todo creation failed: %s", ex.getMessage()), ex);
            throw new TodoCreationFailedException(ex.getMessage());
        }
        return createdTodo;
    }

    public Todo update(Todo modifiedTodo) throws TodoCreationFailedException, TodoNotFoundException {
        Todo updatedTodo = null;
        try {
            LOGGER.debug(String.format("Save a modified Todo synchronously using update(%s)", modifiedTodo.getId()));

            String apiUri = appConfig.getTodoApiUri("/" + modifiedTodo.getId().toString());

            WebClient webClient = WebClient.create(apiUri);

            var todo = new RepositoryTodo(modifiedTodo.getId(), modifiedTodo.getTodoText(),
                    modifiedTodo.getCreatedDateTime(), modifiedTodo.getCompletedDateTime());

            LOGGER.debug("Sending a PUT request with a modified TODO: ", todo);

            ResponseEntity<Todo> updateTodoResponse = webClient.post()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .body(Mono.just(todo), Todo.class)
                    .retrieve()
                    .toEntity(Todo.class)
                    .block();

            if (updateTodoResponse.getStatusCode() == HttpStatus.NOT_FOUND) {
                LOGGER.error(String.format("Todo update(%s) returned a http status code '%s' ('%s') ",
                        modifiedTodo.getId(), Integer.toString(updateTodoResponse.getStatusCodeValue()),
                        updateTodoResponse.getStatusCode().name()));
                throw new TodoNotFoundException(String.format("Todo '%s' does not exist", modifiedTodo.getId()));
            }

            updatedTodo = updateTodoResponse.getBody();
            LOGGER.debug("Received back an updated TODO as a response:", updateTodoResponse.getBody());
        } catch (Exception ex) {
            LOGGER.error(String.format("Todo update(%s) failed: %s", modifiedTodo.getId(), ex.getMessage()), ex);
            throw new TodoUpdateFailedException(ex.getMessage());
        }
        return updatedTodo;
    }

    public void deleteById(UUID id) throws TodoDeleteFailedException, TodoNotFoundException {
        try {
            LOGGER.debug(String.format("Delete a Todo using deleteById('%s')", id));

            String apiUri = appConfig.getTodoApiUri("/" + id.toString());
            WebClient webClient = WebClient.create(apiUri);

            LOGGER.debug(String.format("Sending a DELETE request for Todo Id '%s' ", id));

            var deleteTodoResponse = webClient.delete()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .retrieve()
                    .toEntity(String.class)
                    .block();

            if (deleteTodoResponse.getStatusCode() == HttpStatus.NOT_FOUND) {
                LOGGER.error(String.format("Todo delete(%s) returned a http status code '%s' ('%s') ", id,
                        Integer.toString(deleteTodoResponse.getStatusCodeValue()),
                        deleteTodoResponse.getStatusCode().name()));
                throw new TodoNotFoundException(String.format("Todo '%s' does not exist", id));
            }

            LOGGER.debug(String.format("Received back the following responce: '%s'", deleteTodoResponse));
        } catch (TodoNotFoundException ex) {
            throw ex;
        } catch (Exception ex) {
            LOGGER.error(String.format("Todo deletion failed: %s", ex.getMessage()), ex);
            throw new TodoDeleteFailedException(ex.getMessage());
        }
    }

    public List<Todo> updateAll(List<Todo> modifiedTodos) throws TodoNotFoundException, TodoUpdateFailedException {
        List<Todo> updatedTodos = new ArrayList<Todo>();
        try {
            LOGGER.debug(String.format("Save modified Todos synchronously using updateAll(no of Todos: %s)",
                    modifiedTodos.size()));

            String apiUri = appConfig.getTodoApiUri();

            WebClient webClient = WebClient.create(apiUri);

            var modifiedRepositoryTodos = new ArrayList<RepositoryTodo>();
            for (var e : modifiedTodos) {
                modifiedRepositoryTodos.add(new RepositoryTodo(e.getId(), e.getTodoText(), e.getCreatedDateTime(),
                        e.getCompletedDateTime()));
            }
            LOGGER.debug(String.format("Sending a PUT request with a list of modified TODOs (no of Todos: %s): ",
                    modifiedTodos.size()));

            ResponseEntity<RepositoryTodoList> updateTodosResponse = webClient.post()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .body(Mono.just(modifiedRepositoryTodos), RepositoryTodoList.class)
                    .retrieve()
                    .toEntity(RepositoryTodoList.class)
                    .block();

            if (updateTodosResponse.getStatusCode() == HttpStatus.NOT_FOUND) {
                LOGGER.error(String.format("Todo updateAll(no of Todos: %s) returned a http status code '%s' ('%s') ",
                        modifiedTodos.size(), Integer.toString(updateTodosResponse.getStatusCodeValue()),
                        updateTodosResponse.getStatusCode().name()));
                throw new TodoNotFoundException(String.format("Some or all Todos do not not exist"));
            }

            var updatedTodoEntities = updateTodosResponse.getBody();
            for (var e : updatedTodoEntities) {
                updatedTodos.add(new Todo(e.getId(), e.getTodoText(), e.getCreatedDateTime(), e.getCompletedDateTime(),
                        e.getCompletedDateTime() != null));
            }
            LOGGER.debug("Received back a list of updated TODOs as a response:", updateTodosResponse.getBody());
        } catch (TodoNotFoundException ex) {
            throw ex;
        } catch (Exception ex) {
            LOGGER.error(String.format("Todos update failed: %s", ex.getMessage()), ex);
            throw new TodoUpdateFailedException(ex.getMessage());
        }
        return updatedTodos;
    }

    public String getApiVersion() {

        String retVal = "unknown";

        LOGGER.debug(String.format("Retrieving an API Version synchronously using getApiVersion()"));

        try {

            String apiUri = appConfig.getApiVersionUri();

            WebClient webClient = WebClient.create(apiUri);

            var getVersionResponse = webClient.get()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .retrieve()
                    .toEntity(String.class)
                    .block();

            retVal = getVersionResponse.getBody();

            LOGGER.debug(String.format("Received back this version as a response: %s", retVal));
        } catch (Exception ex) {
            LOGGER.error(String.format("Retrieving the API version failed: %s", ex.getMessage()), ex);
            retVal = "unknown";
        }
        if (retVal == null)
            retVal = "unknown";

        return retVal;
    }
}

class RepositoryTodo {

    private UUID id;

    private String todoText;

    private Date createdDateTime;

    private Date completedDateTime;

    public RepositoryTodo(UUID id, String todoText, Date createdDateTime, Date completedDateTime) {
        this.id = id;
        this.todoText = todoText;
        this.createdDateTime = createdDateTime;
        this.completedDateTime = completedDateTime;
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
}

class RepositoryTodoList extends ArrayList<RepositoryTodo> {

}

class TodoList extends ArrayList<Todo> {

}