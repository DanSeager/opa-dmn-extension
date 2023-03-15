# Workato DMN Evaluator Extension

This OPA extension implements Camunda's DMN Decision Engine to allow
the execution of complex rules from Workato.

## Building extension

Steps to build an extension:

1. Install the latest Java 8 SDK
2. Use `./gradlew jar` command to bootstrap Gradle and build the project.
3. The output is in `build/libs`.

## Installing the extension to OPA

1. Add a new directory called `ext` under Workato agent install directory.
2. Copy the extension JAR file to `ext` directory. Pre-build jar: [opa-dmn-extension-0.1.jar](build/libs/opa-dmn-extension-0.1.jar).  Dependencies are packaged within this JAR so do not need to be copied manual to the `ext` directory.
3. Update the `config/config.yml` to add the `ext` file to class path.

```yml
server:
  classpath: 
    - ext
    - other classpaths...
```

4. Update the `conf/config.yml` to configure the new extension.

```yml
extensions:
  dmn_evaluator:
    controllerClass: com.workato.onprem.DmnExtension
```

## Custom SDK for the extension

The corresponding custom SDK can be found here in this repo as well.

Link: [dmn-evaluator-connector.rb](custom-sdk/dmn-evaluator-connector.rb)

Create a new Custom SDK in your Workato workspace and use it with the OPA extension.