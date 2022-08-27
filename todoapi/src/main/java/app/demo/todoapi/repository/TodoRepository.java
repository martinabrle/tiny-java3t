package app.demo.todoapi.repository;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

import app.demo.todoapi.entity.Todo;

public interface TodoRepository extends JpaRepository<Todo, UUID> {
    List<Todo> findByTodoText(String infix);
}