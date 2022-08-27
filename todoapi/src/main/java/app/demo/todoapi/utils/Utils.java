package app.demo.todoapi.utils;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

public class Utils {
    private static DateFormat DATE_FORMAT = new SimpleDateFormat("yyyy-MM-dd HH:mm a z");

    public static String toJsonValueContent(String value) {
        if (value == null)
          return "null";
        return value.replace("\'", "\\'").replace("\"", "\\\"");
    }
    
    public static String toJsonValueContent(Date value) {
        if (value == null)
          return "null";
        return DATE_FORMAT.format(value);
    }

    public static String shortenString(String value) {
			
      if (value == null) {
        return "";
      }
      
      if (value.length() <= 5)
      {
        return value;
      }

      return value.substring(0, 4) + "...";
    }
}
