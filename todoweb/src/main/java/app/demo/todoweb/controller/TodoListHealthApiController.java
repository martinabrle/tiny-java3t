package app.demo.todoweb.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

import app.demo.todoweb.service.TodoService;
import app.demo.todoweb.utils.AppLogger;

import java.util.Random;

@RestController
public class TodoListHealthApiController {

	private TodoService todoService;

	private static Random randomGenerator = new Random();

	public static final AppLogger LOGGER = new AppLogger(TodoListHealthApiController.class);

	@Autowired
	public TodoListHealthApiController(TodoService service) {
		try {
			this.todoService = service;
		} catch (Exception ignException) {
			this.todoService = null;
		}
	}

	@GetMapping(value = { "/health" }, produces = MediaType.APPLICATION_JSON_VALUE)
	@ResponseBody
	public ResponseEntity<String> getHealth() {

		LOGGER.debug("Healthiness probe called");

		var random = randomGenerator.nextDouble();
		if (random > 0.96) {
			if (random > 0.98) {
				LOGGER.debug("Healthiness returns 'RANDOM_ERROR_INTERNAL'");
				return new ResponseEntity<String>("RANDOM_ERROR_INTERNAL", HttpStatus.INTERNAL_SERVER_ERROR);
			}
			LOGGER.debug("Healthiness returns 'RANDOM_ERROR_BAD_REQUEST'");
			return new ResponseEntity<String>("RANDOM_ERROR_BAD_REQUEST", HttpStatus.BAD_REQUEST);
		}
		LOGGER.debug("Healthiness returns 'OK'");
		return new ResponseEntity<String>("OK", HttpStatus.OK);
	}

	@GetMapping(value = { "/health/live" }, produces = MediaType.APPLICATION_JSON_VALUE)
	@ResponseBody
	public ResponseEntity<String> getLive() {
		LOGGER.debug("Liveness probe called");

		try {
			todoService.getTodos();
		} catch (Exception ignoreException) {
			return new ResponseEntity<String>("BACKEND_ERROR", HttpStatus.INTERNAL_SERVER_ERROR);
		}
		return new ResponseEntity<String>("OK", HttpStatus.OK);
	}

	@GetMapping(value = { "/health/warmup" }, produces = MediaType.APPLICATION_JSON_VALUE)
	@ResponseBody
	public ResponseEntity<String> warm() {
		LOGGER.debug("Warm-Up called");

		try {
			todoService.getTodos();
		} catch (Exception ignoreException) {
			return new ResponseEntity<String>("BACKEND_ERROR", HttpStatus.INTERNAL_SERVER_ERROR);
		}
		return new ResponseEntity<String>("OK", HttpStatus.OK);
	}
}