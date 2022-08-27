package app.demo.todoapi.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import app.demo.todoapi.utils.AppLogger;

@Controller
public class TodoListWebController {

	public static final AppLogger LOGGER = new AppLogger(TodoListWebController.class);

	// private TodoService todoService;

	// @Autowired
	// public TodoListWebController(TodoService service) {
	// this.todoService = service;
	// }

	@GetMapping("/")
	public String getIndex(Model model) {
		LOGGER.debug("TODO GET called with action '/'");
		String version = "Unknown";
		try {
			version = this.getClass().getPackage().getImplementationVersion();
		} catch (Exception ignoreException) {
			LOGGER.error("An error has occurred while trying to retrieve the package version.");
		}

		model.addAttribute("VERSION", version);

		return "todo";
	}
}