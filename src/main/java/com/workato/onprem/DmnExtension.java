/*
 * Copyright (c) 2018 MyCompany, Inc. All rights reserved.
 */

package com.workato.onprem;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.io.IOUtils;
import org.camunda.bpm.dmn.engine.DmnDecision;
import org.camunda.bpm.dmn.engine.DmnDecisionResult;
import org.camunda.bpm.dmn.engine.DmnEngine;
import org.camunda.bpm.dmn.engine.DmnEngineConfiguration;
import org.camunda.bpm.engine.variable.VariableMap;
import org.camunda.bpm.engine.variable.Variables;

@Controller
public class DmnExtension {

    @RequestMapping(path = "/executeDmn", method = RequestMethod.POST)
    public @ResponseBody Map<String, Object> executeDmn(@RequestBody Map<String, Object> body) throws Exception {
        String decisionModel = new String(Base64.getDecoder().decode(((String) body.get("decision_model")).getBytes()));
        String decisionId = (String) body.get("decision_id");

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> decisionVariables = (List<Map<String, Object>>) body.get("decision_variables");

        System.out.println("decisionModel: " + decisionModel);
        System.out.println("decisionId: " + decisionId);
        System.out.println("decisionVariables: " + decisionVariables);

        return evaluateDmn(decisionModel, decisionId, decisionVariables);
    }

    @RequestMapping(path = "/testDmn", method = RequestMethod.GET)
    public @ResponseBody Map<String, Object> testDmn() throws Exception {
        System.out.println("testDnm Executed");
        return null;
    }

    public static Map<String, Object> evaluateDmn(String decisionModel, String decisionId,
            List<Map<String, Object>> decisionVariables) {

        Map<String, Object> response = new HashMap<>();
        String error = "";
        try {
            InputStream decisionStream = IOUtils.toInputStream(decisionModel, "UTF-8");

            try {
                DmnEngine dmnEngine = DmnEngineConfiguration
                        .createDefaultDmnEngineConfiguration()
                        .buildEngine();

                System.out.println("decisionModel (evaluateDmn): " + decisionModel);

                DmnDecision decision = dmnEngine.parseDecision(decisionId, decisionStream);

                VariableMap variables = Variables.createVariables();

                if (decisionVariables != null) {
                    for (Map<String, Object> variable : decisionVariables) {
                        variables.putValue((String) variable.get("name"), variable.get("value"));
                    }
                }

                System.out.println("decision name: " + decision.getName());

                DmnDecisionResult resultTable = dmnEngine.evaluateDecision(decision, variables);
                response.put("results", resultTable.getResultList());
            } catch (Exception e) {
                System.out.println(e.getStackTrace());
                error = e.getLocalizedMessage();
                response.put("error", error);
            } finally {
                decisionStream.close();
            }

        } catch (IOException e) {
            System.out.println(e.getStackTrace());
            error = e.getLocalizedMessage();
        }

        System.out.println(response);
        return response;

    }

    public static void main(String[] args) throws IOException {

        String content = new String(Files.readAllBytes(Paths.get("src/main/resources/simulation.dmn")));

        List<Map<String, Object>> vars = new ArrayList<Map<String, Object>>();

        Map<String, Object> m = new HashMap<String, Object>();
        m.put("name", "tableNumber");
        m.put("value", "11");
        vars.add(m);

        evaluateDmn(content, "table", vars);
    }
}
