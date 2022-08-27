package app.demo.todoapi.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.EmbeddedDatabaseConnection;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.context.SpringBootTest;

import app.demo.todoapi.DatabaseLoader;
import app.demo.todoapi.dto.Todo;
import app.demo.todoapi.repository.TodoRepository;
import app.demo.todoapi.service.TodoService;
import app.demo.todoapi.utils.AppLogger;

@SpringBootTest
@AutoConfigureTestDatabase(connection = EmbeddedDatabaseConnection.H2)
public class TodoServiceTest {
    
    public static final AppLogger LOGGER = new AppLogger(TodoServiceTest.class);

	@Autowired 
    private TodoService todoService;

	@Autowired 
    private TodoRepository todoRepository;
    
    private UUID existingTodoId = null;

    @BeforeEach
    void setUp() {
        if (existingTodoId == null ) {
            DatabaseLoader.initRepoWithDemoData(todoRepository);
            existingTodoId = UUID.fromString("00000000-0000-0000-0000-000000000002");
        }
    }

    @Test
    void always_retrieveTodos() {

        assertDoesNotThrow(() -> {
            var retrievedTodos = todoService.getTodos();

            if (retrievedTodos == null || retrievedTodos.size() == 0) {
                throw new Exception("Empty Todo List retrieved.");
            }
        });
    }

    @Test
    void whenValidTodoId_thenTodoShouldBeFound() {

        assertDoesNotThrow(() -> {
            Todo retrievedTodo = todoService.getTodo(existingTodoId);
            if (retrievedTodo.getId() != existingTodoId) {
                throw new Exception("Invalid Todo retrieved.");
            }
        });
    }

    @Test
    void whenInvalidTodoId_thenTodoShouldNotBeFound() {

        UUID todoId = UUID.fromString("11111111-0000-0000-0000-000000000002");
        
        assertThrows(Exception.class,() -> {
            todoService.getTodo(todoId);
        });
    }

    @Test
    void whenValidTodo_thenTodoShouldBeCreated() {

        assertDoesNotThrow(() -> {
            Todo createdTodo = todoService.createTodo("Test it all");
            if (createdTodo.getId() == null || createdTodo.getTodoText().compareTo("Test it all") != 0) {
                throw new Exception("Invalid Todo created.");
            }
            todoService.deleteTodo(createdTodo.getId());
        });
    }

    @Test
    void whenInvalidTodo_thenTodoShouldNotBeCreated() {

        assertThrows(Exception.class, () -> {
            Todo createdTodo = todoService.createTodo("");
            if (createdTodo != null) {
                throw new Exception("Invalid Todo created.");
            }
        });
    }

    @Test
    void whenValidTodoId_thenTodoShouldBeDeleted() {

        assertDoesNotThrow(() -> {
            Todo createdTodo = todoService.createTodo("Test deleting Todos");
            if (createdTodo.getId() == null) {
                throw new Exception("Failed creating the testing Todo.");
            }
            todoService.deleteTodo(createdTodo.getId());
        });
    }

    @Test
    void whenInvalidTodoId_thenTodoShouldNotBeDeleted() {

        assertThrows(Exception.class, () -> {
            UUID todoId = UUID.fromString("11111111-0000-0000-0000-000000000002");
            
            todoService.deleteTodo(todoId);
        });
    }

    @Test
    void whenValidTodo_thenTodoShouldBeUpdated() {

        assertDoesNotThrow(() -> {
            Todo createdTodo = todoService.createTodo("Test it all");
            if (createdTodo.getId() == null || createdTodo.getTodoText().compareTo("Test it all") != 0) {
                throw new Exception("Invalid Todo created.");
            }

            createdTodo.setTodoText("Update it all");
            
            Todo updatedTodo = todoService.updateTodo(createdTodo);
            if (updatedTodo.getId() != createdTodo.getId() || updatedTodo.getTodoText().compareTo("Update it all") != 0) {
                throw new Exception("Update failed.");
            }

            todoService.deleteTodo(createdTodo.getId());

        });
    }

    
    @Test
    void whenInvalidTodo_thenTodoShouldNotBeUpdated() {

        assertThrows(Exception.class, () -> {
            Todo createdTodo = todoService.createTodo("Test it all");
            if (createdTodo.getId() == null || createdTodo.getTodoText().compareTo("Test it all") != 0) {
                throw new Exception("Invalid Todo created.");
            }

            createdTodo.setTodoText("");
            
            try
            {
                todoService.updateTodo(createdTodo);
                todoService.deleteTodo(createdTodo.getId());
            }
            catch (Exception ex) {
                todoService.deleteTodo(createdTodo.getId());
                throw ex;
            }
        });
    }
}
