package app.demo.todoapi;

import java.util.Date;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import app.demo.todoapi.repository.TodoRepository;
import app.demo.todoapi.utils.AppLogger;

@Component
public class DatabaseLoader implements CommandLineRunner {

        public static final AppLogger LOGGER = new AppLogger(DatabaseLoader.class);

        private final TodoRepository todoRepository;

        @Autowired
        private AppConfig appConfig;

        @Autowired
        public DatabaseLoader(TodoRepository repository) {
                todoRepository = repository;
        }

        @Override
        public void run(String... strings) throws Exception {
                if (loadDemoData()) {
                        LOGGER.debug("Loading default data");
                        DatabaseLoader.initRepoWithDemoData(todoRepository);
                } else {
                        LOGGER.debug("Skipping demo data load");
                }
        }

        public static void initRepoWithDemoData(TodoRepository todoRepository) {
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000001"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000001"),
                                                        "Create Stark Enterprises",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000002"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000002"),
                                                        "Invent the first Iron Man Suit",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000003"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000003"),
                                                        "Become a Hero",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000004"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000004"),
                                                        "Help build S.H.I.E.L.D.",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000005"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000005"),
                                                        "Form the Avengers",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000006"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000006"),
                                                        "Put Hawkeye on the right path",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000007"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000007"),
                                                        "Make Stark Industries a massive success",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000008"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000008"),
                                                        "Keep escaping death in the most Tony Stark way possible",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000009"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000009"),
                                                        "Learn Spring boot",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000010"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000010"),
                                                        "Deploy a multi tier Spring boot app into Azure",
                                                        new Date(),
                                                        null));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000011"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000011"),
                                                        "Make a hash of everything",
                                                        new Date(),
                                                        new Date()));
                }
                if (!todoRepository.existsById(UUID.fromString("00000000-0000-0000-0000-000000000012"))) {
                        todoRepository.save(
                                        new app.demo.todoapi.entity.Todo(
                                                        UUID.fromString("00000000-0000-0000-0000-000000000012"),
                                                        "Ask Petteri to fix it",
                                                        new Date(),
                                                        new Date()));
                }
        }

        private boolean loadDemoData() {
                //return appConfig != null && appConfig.getLoadDemoData();
                return true;
        }
}