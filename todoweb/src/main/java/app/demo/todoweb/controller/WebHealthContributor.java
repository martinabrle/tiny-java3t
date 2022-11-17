//currently investigating if actuator needs to be extended
package app.demo.todoweb.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.web.bind.annotation.RestController;

import app.demo.todoweb.service.TodoService;
import app.demo.todoweb.utils.AppLogger;

@RestController
public class WebHealthContributor implements HealthIndicator {

	@Autowired
	private TodoService todoService;

	public static final AppLogger LOGGER = new AppLogger(WebHealthContributor.class);

	@Override
	public Health health() {

		LOGGER.debug("Web health probe called");

		try {
			todoService.getTodos();
		} catch (Exception ex) {
			LOGGER.error("Web health probe failed: ", ex);
			return Health.outOfService().withException(ex).build();
		}
		LOGGER.debug("Web health probe returned OK");
		return Health.up().build();
	}
}