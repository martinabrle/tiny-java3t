package app.demo.todoapi.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import app.demo.todoapi.AppConfig;
import app.demo.todoapi.utils.AppLogger;

@Controller
public class InfoWebController {

	public static final AppLogger LOGGER = new AppLogger(InfoWebController.class);

	@GetMapping("/")
	public String getIndex(Model model) {
		LOGGER.debug("TODO GET called with action '/'");

		model.addAttribute("version", new AppConfig().getVersion());
		model.addAttribute("environment", new AppConfig().getEnvironment());

		return "info";
	}
}