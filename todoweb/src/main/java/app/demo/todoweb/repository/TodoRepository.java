package app.demo.todoweb.repository;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

import app.demo.todoweb.entity.Todo;

public interface TodoRepository extends JpaRepository<Todo, UUID> {
    List<Todo> findByTodoText(String infix);
}