package app.demo.todoweb;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import com.microsoft.applicationinsights.TelemetryConfiguration;

import app.demo.todoweb.utils.AppEnvironment;
import app.demo.todoweb.utils.AppLogger;
import app.demo.todoweb.utils.FileCache;

@SpringBootApplication
public class TodoApplication {

	public static final AppLogger LOGGER = new AppLogger(TodoApplication.class);

	public static final String CURRENT_DIR = AppEnvironment.GetCurrentDirectory();
	public static final String CURRENT_SYSTEM_DIR = AppEnvironment.GetSystemCurrentDirectory();
	public static final String APPLICATION_INSIGHTS = new FileCache().cacheEmbededFile("ApplicationInsights.xml");
	public static final String AI_AGENT = new FileCache().cacheEmbededFile("AI-Agent.xml");

	private static boolean STARTUP_FINISHED = false;

	public static void main(String[] args) {
		System.out.println(String.format("Starting '%s'", TodoApplication.class.getName()));


		SpringApplication.run(TodoApplication.class, args);

		STARTUP_FINISHED = true;

		configureTelemetry();

		System.out.println(String.format("Finishing '%s'", TodoApplication.class.getName()));
	}

	private static void configureTelemetry() {

		LOGGER.debug("Configuring telemetry");

		if (TelemetryConfiguration.getActive() != null) {
			TelemetryConfiguration.getActive().setRoleName("Web Frontend + API");
		}
	}

	public static boolean isInitialized() {
		return STARTUP_FINISHED;
	}
}
