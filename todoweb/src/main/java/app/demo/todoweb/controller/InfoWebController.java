package app.demo.todoweb.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import app.demo.todoweb.AppConfig;
import app.demo.todoweb.service.TodoService;
import app.demo.todoweb.utils.AppLogger;

@Controller
public class InfoWebController {

	public static final AppLogger LOGGER = new AppLogger(InfoWebController.class);

	private TodoService todoService;

	@Autowired
	public InfoWebController(TodoService service) {
		this.todoService = service;
	}

	@GetMapping("/info")
	public String getIndex(Model model) {
		LOGGER.debug("TODO GET called with action '/info'");

		model.addAttribute("version", new AppConfig().getVersion());
		model.addAttribute("apiVersion", todoService.getApiVersion());
		model.addAttribute("environment", new AppConfig().getEnvironment());

		return "info";
	}
}