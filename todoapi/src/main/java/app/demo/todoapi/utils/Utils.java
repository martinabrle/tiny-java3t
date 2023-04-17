package app.demo.todoapi.utils;

import java.io.InputStream;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;

import app.demo.todoapi.TodoApplication;

public class Utils {
  public static final AppLogger LOGGER = new AppLogger(Utils.class);

  private static DateFormat DATE_FORMAT = new SimpleDateFormat("yyyy-MM-dd HH:mm a z");
  private static String GIT_COMMIT_ID = "";

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

    if (value.length() <= 5) {
      return value;
    }

    return value.substring(0, 4) + "...";
  }

  public static String getCommitId() {
    if (GIT_COMMIT_ID != null && !GIT_COMMIT_ID.isEmpty()) {
      return GIT_COMMIT_ID;
    }

    Package mainPackage = TodoApplication.class.getPackage();
    // String version = mainPackage.getImplementationVersion();
    String groupId = mainPackage.getName();
    String artifactId = mainPackage.getImplementationTitle();
    if (groupId.endsWith("." + artifactId)) {
      groupId = groupId.substring(0, groupId.lastIndexOf("." + artifactId));
    }

    try {
      // LOGGER.info("Retrieving from: " + "META-INF/maven/" + groupId + "/" +
      // artifactId + "/pom.xml");

      // InputStream inputStream = new Utils().getClass().getClassLoader()
      // .getResourceAsStream("META-INF/maven/app.demo/todoapi/pom.xml");
      InputStream inputStream = new Utils().getClass().getClassLoader()
          .getResourceAsStream("META-INF/maven/" + groupId + "/" + artifactId +
              "/pom.xml");
      DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
      DocumentBuilder documentBuilder = dbf.newDocumentBuilder();
      Document doc = documentBuilder.parse(inputStream);
      var nodeList = doc.getChildNodes();
      for (int i = 0; i < nodeList.getLength(); i++) {
        var node = nodeList.item(i);
        if ("project".compareTo(node.getNodeName()) == 0) {
          var childNodeList = node.getChildNodes();
          for (int j = 0; j < childNodeList.getLength(); j++) {
            var childNode = childNodeList.item(j);
            if (childNode != null && childNode.getNodeType() == org.w3c.dom.Node.COMMENT_NODE) {
              String commentContent = childNode.getTextContent();
              if (commentContent != null && commentContent.contains("GIT_COMMIT_ID")) {
                commentContent = commentContent.replace(" ", "");
                commentContent = commentContent.replace("GIT_COMMIT_ID:", "");
                System.out.println(commentContent);
                if (!commentContent.isEmpty()) {
                  GIT_COMMIT_ID = commentContent;
                  return GIT_COMMIT_ID;
                }
              }
            }
          }
        }
      }
      inputStream.close();
    } catch (Exception e) {
      e.printStackTrace();
      return e.getMessage();
    }
    GIT_COMMIT_ID = "Error";
    return GIT_COMMIT_ID;
  }
}
