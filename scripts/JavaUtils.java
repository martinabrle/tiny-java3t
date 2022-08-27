import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Scanner;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

import org.w3c.dom.Document;

public class JavaUtils {
    public static void main(String args[]) {
        // String[] args2 = {"-get_highest_semver_from_file", "./scripts/container_tags.txt"};
        // args = args2;

        try {

            Map<String, List<String>> params = parseParms(args);
            if (params == null || params.isEmpty()) {
                throw new Exception("Wrong parameters");
            }
            if (params.containsKey("get_pom_version")) {
                var options = params.get("get_pom_version");
                var fileName = options.get(0);
                if (fileName == null || fileName.isEmpty()) {
                    throw new Exception("Wrong parameters");
                }
                displayPomVersion(fileName);
            } else if (params.containsKey("update_pom_version")) {
                var options = params.get("update_pom_version");
                var fileName = options.get(0);
                var version = options.get(1);
                var newFileName = options.get(2);
                if (fileName == null || fileName.isEmpty() || version == null || version.isEmpty()
                        || newFileName == null || newFileName.isEmpty()) {
                    throw new Exception("Wrong parameters");
                }
                updatePomVersion(fileName, version, newFileName);
            } else if (params.containsKey("get_highest_semver_from_file")) {
                var options = params.get("get_highest_semver_from_file");
                var fileName = options.get(0);
                if (fileName == null || fileName.isEmpty()) {
                    throw new Exception("Wrong parameters");
                }
                displayHighestSemVerFromFile(fileName);
            } else if (params.containsKey("get_higher_semver")) {
                var options = params.get("get_higher_semver");
                var version1 = options.get(0);
                var version2 = options.get(1);
                if (version1 == null || version1.isEmpty() || version2 == null || version2.isEmpty()) {
                    throw new Exception("Wrong parameters");
                }
                displayHigherSemVer(version1, version2);
            } else if (params.containsKey("increase_semver")) {
                var options = params.get("increase_semver");
                var version = options.get(0);
                if (version == null || version.isEmpty()) {
                    throw new Exception("Wrong parameters");
                }
                displayIncreasedSemVer(version);
            } else {
                displayHelp();
                System.exit(-1);
            }

        } catch (Exception ignoreException) {
            System.err.println("An error has occured.");
            displayHelp();
            System.exit(-1);
        }
    }

    private static void displayIncreasedSemVer(String version) {
        String newVersionString = increaseSemVer(version);
        System.out.println(newVersionString);
    }

    private static String increaseSemVer(String version) {
        int[] parsedVersion = getParsedSemVer(version);
        String semVerSuffix = getParsedSemVerSuffix(version);
        parsedVersion[2]++;
        String newVersionString = Integer.toString(parsedVersion[0]) + "." + Integer.toString(parsedVersion[1]) + "."
                + Integer.toString(parsedVersion[2]) + semVerSuffix;

        return newVersionString;
    }

    private static void displayHigherSemVer(String version1, String version2) {

        var higherSemVer = getHigherSemVerString(version1, version2);

        System.out.println(higherSemVer);
    }

    private static String getHigherSemVerString(String version1, String version2) {
        version1 = version1.trim();
        version2 = version2.trim();

        int[] parsedVersion1 = getParsedSemVer(version1);
        int[] parsedVersion2 = getParsedSemVer(version2);

        var higherSemVer = getHigherSemVerInt(parsedVersion1, parsedVersion2);
        if (higherSemVer == 0) {
            if (version1.compareToIgnoreCase(version2) < 0) {
                return version2;
            }
            return version1;
        }
        if (higherSemVer == 1) {
            return version1;
        }
        return version2;
    }

    private static int getHigherSemVerInt(int[] parsedVersion1, int[] parsedVersion2) {
        if (parsedVersion1[0] > parsedVersion2[0]) {
            return 1;
        }
        if (parsedVersion1[0] < parsedVersion2[0]) {
            return 2;
        }
        if (parsedVersion1[1] > parsedVersion2[1]) {
            return 1;
        }
        if (parsedVersion1[1] < parsedVersion2[1]) {
            return 2;
        }
        if (parsedVersion1[2] > parsedVersion2[2]) {
            return 1;
        }
        if (parsedVersion1[2] < parsedVersion2[2]) {
            return 2;
        }
        return 0;
    }

    private static void displayHighestSemVerFromFile(String fileName) throws Exception {
        Scanner scanner = null;
        String highestSemVer = "0.0.0";
        try {
            scanner = new Scanner(new File(fileName));
            scanner.useDelimiter("\"|\n| |\'");
            while (scanner.hasNext()) {
                String token = scanner.next();
                if (isSemVer(token)) {
                    highestSemVer = getHigherSemVerString(highestSemVer, token);
                }
            }
        } catch (Exception ignoreException) {
            System.err.println(String.format("Unable to read the file '%s'.", fileName));
            throw new Exception(String.format("Unable to read the file '%s'.", fileName));
        } finally {
            if (scanner != null) {
                try {
                    scanner.close();
                } catch (Exception ignoreException) {
                    System.err.println(String.format("Unable to close the file '%s'.", fileName));
                    throw new Exception(String.format("Unable to close the file '%s'.", fileName));
                }
            }
        }
        System.out.println(highestSemVer);
    }

    private static void updatePomVersion(String fileName, String version, String newFileName) throws Exception {
        boolean updated = false;

        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setValidating(false);
        factory.setIgnoringElementContentWhitespace(true);
        DocumentBuilder builder = factory.newDocumentBuilder();
        File file = new File(fileName);
        if (!file.exists()) {
            System.err.println(String.format("File '%s' does not exist.", fileName));
            throw new Exception(String.format("File '%s' does not exist.", fileName));
        }
        Document doc = builder.parse(file);
        var nodeList = doc.getElementsByTagName("version");
        for (int i = 0; i < nodeList.getLength(); i++) {
            var node = nodeList.item(i);

            String parentNodeName = node.getParentNode().getNodeName();

            if (parentNodeName.compareTo("project") == 0) {
                node.setTextContent(version);
                updated = true;
            }
        }
        if (!updated) {
            System.err.println(
                    String.format("An error has occured, while updating the project version in file '%s'", fileName));
            throw new Exception(
                    String.format("An error has occured, while updating the project version in file '%s'", fileName));
        }
        DOMSource source = new DOMSource(doc);
        StreamResult output = new StreamResult(new File(newFileName));
        TransformerFactory.newInstance().newTransformer().transform(source, output);
    }

    private static void displayPomVersion(String fileName) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setValidating(false);
        factory.setIgnoringElementContentWhitespace(true);
        DocumentBuilder builder = factory.newDocumentBuilder();
        File file = new File(fileName);
        if (!file.exists()) {
            System.err.println(String.format("File '%s' does not exist.", fileName));
            throw new Exception(String.format("File '%s' does not exist.", fileName));
        }
        Document doc = builder.parse(file);
        var nodeList = doc.getElementsByTagName("version");
        for (int i = 0; i < nodeList.getLength(); i++) {
            var node = nodeList.item(i);

            String parentNodeName = node.getParentNode().getNodeName();

            if (parentNodeName.compareTo("project") == 0) {
                String nodeValue = node.getTextContent();
                if (nodeValue != null) {

                    nodeValue = nodeValue.trim();
                    if (!nodeValue.isEmpty()) {
                        System.out.println(nodeValue);
                        return;
                    }
                }
            }
        }
    }

    private static void displayHelp() {
        System.out.println(String.format("USAGE: java %s.java [ARGS]", getShortClassName()));
        System.out.println("\t-get_pom_version ./pom.xml - retrieves the current version from a pom.xml file");
        System.out
                .println(
                        "\t-update_pom_version ./pom.xml 3.11.0 - saves the new version (3.11.0 into the pom.xml file)");
        System.out.println(
                "\t-get_highest_semver_from_file ./file_with_semver_numbers.txt - retrieves the highest SemVer version from a text file");
        System.out.println("\t-get_higher_semver 1.3.4 1.3.5 - returns a higher semver from a list (of two)");
        System.out.println("\t-increase_semver 1.3.4 - increases the semver (patch number)");
    }

    private static Map<String, List<String>> parseParms(String args[]) {
        final Map<String, List<String>> params = new HashMap<>();

        List<String> options = null;
        try {
            for (int i = 0; i < args.length; i++) {
                final String a = args[i];

                if (a.charAt(0) == '-') {
                    if (a.length() < 2) {
                        System.err.println(String.format("Error at argument '%s'", a.toString()));
                        return null;
                    }

                    options = new ArrayList<>();
                    params.put(a.substring(1), options);
                } else if (options != null) {
                    options.add(a);
                } else {
                    System.err.println("Illegal parameter usage");
                    return null;
                }
            }
        } catch (Exception ignoreException) {
            System.err.println(
                    String.format("An error occurrred while parsing parameters: %s", ignoreException.getMessage()));
            return null;

        }
        return params;
    }

    private static String getShortClassName() {
        String retVal = JavaUtils.class.getName();
        if (retVal == null) {
            retVal = "JavaUtils.java";
        }
        if (retVal != null && retVal.contains(".")) {
            retVal = retVal.substring(retVal.lastIndexOf(".") + 1);
        }
        return retVal;
    }

    private static int[] getParsedSemVer(String version) {
        var parsedVersion = version.split("\\.");
        int[] versionInfo = { 0, 0, 0 };
        int j = 0;
        for (int i = 0; i < parsedVersion.length; i++) {
            if (parsedVersion[i] != null && !parsedVersion[i].isEmpty()) {
                String tmpString = getLeadingNumbers(parsedVersion[i].trim());
                if (!tmpString.isEmpty()) {
                    try {
                        var tmpVer = Integer.parseInt(tmpString);
                        if (parsedVersion[i].trim().contains(Integer.toString(tmpVer))) {
                            versionInfo[j] = tmpVer;
                            j++;
                            if (j == 3) {
                                return versionInfo;
                            }

                        }
                    } catch (Exception ignoreException) {
                        continue;
                    }
                } else if (j > 0) {
                    // When detecting a first non-integer substring, following an integer
                    // (major/minor/path), finish right there
                    return versionInfo;
                }
            }
        }
        return versionInfo;
    }

    private static String getParsedSemVerSuffix(String version) {
        if (version == null || version.isEmpty() || !version.contains(".")) {
            return "";
        }
        String suffix = version.substring(version.lastIndexOf(".") + 1);
        for (int i = 0; i < suffix.length(); i++) {
            if (suffix.charAt(i) < '0' || suffix.charAt(i) > '9') {
                return suffix.substring(i);
            }
        }
        return "";
    }

    private static String getLeadingNumbers(String parm) {
        String retVal = "";
        for (int i = 0; i < parm.length(); i++) {
            if (parm.charAt(i) >= '0' && parm.charAt(i) <= '9') {
                retVal = retVal + parm.charAt(i);
            }
        }
        return retVal;
    }

    private static boolean isSemVer(String token) {
        if (token == null || token.isEmpty()) {
            return false;
        }
        String tmp = token.trim();

        try {
            int tmpInt = Integer.parseInt("" + tmp.charAt(0));
            if (Integer.toString(tmpInt).charAt(0) == tmp.charAt(0)) {
                return true;
            }
        } catch (Exception ignoreException) {
            return false;
        }
        return false;
    }
}
