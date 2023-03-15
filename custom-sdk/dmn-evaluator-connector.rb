{
  title: "On-prem DMN Evaluator",
  secure_tunnel: true,

  connection: {
    fields: [
      {
        name: "profile",
        hint: "On-prem DNM Evaluator connection profile",
      },
    ],
    authorization: { type: "none" },
  },

  test: lambda do |connection|
    get("http://localhost/ext/#{connection["profile"]}/testDmn")
      .headers('X-Workato-Connector': "enforce")
  end,

  object_definitions: {
    execute_dmn_input: {
      fields: lambda do |_connection, config_fields, object_definitions|
        schema = []
        required_decisions = []

        if config_fields["sample_document"].present?
          #           call("validate_decision_model", config_fields["sample_document"])
          schema[0] =
            {
              name: "decision_id",
              hint: "Id of the decision to be executed",
              control_type: "select",
              optional: false,
              extends_schema: true,
              options: call("get_decisions", config_fields["sample_document"]),
            }
        end
        if config_fields["decision_id"].present?
          required_decisions = call("get_required_decisions", config_fields["sample_document"], config_fields["decision_id"])
          schema[1] =
            {
              name: "decision_variables",
              type: "object",
              optional: false,
              sticky: true,
              extends_schema: true,
              properties: call("get_input_variables", config_fields["sample_document"], config_fields["decision_id"]),
            }
        end
        if required_decisions.present?
          required_decisions.each do |decision_id|
            schema[schema.length] = {
              name: "required_decision_variables",
              label: "Required decision variables (#{decision_id.first()})",
              type: "object",
              optional: false,
              sticky: true,
              properties: call("get_input_variables", config_fields["sample_document"], decision_id),
            }
          end
        end

        schema
      end,
    },
    execute_dmn_output: {
      fields: lambda do |_connection, config_fields, object_definitions|
        if config_fields["decision_id"].present?
          variables = call("get_output_variables", config_fields["sample_document"], config_fields["decision_id"])
          if variables.present?
            [
              {
                name: "results",
                type: "array",
                of: "object",
                properties: call("get_output_variables", config_fields["sample_document"], config_fields["decision_id"]).presence || [],
              },
              { name: "error", type: "string" },
            ]
          elsif [
            { name: "error", type: "string" },
          ]
          end
        end
      end,
    },
  },

  actions: {
    execute_dmn: {
      title: "Execute DMN",
      description: 'Execute <span class="provider">DMN</span> rules',

      config_fields: [
        {
          name: "sample_document",
          hint: "Used to generate the Input parameters and Workato output datatree for use in subsequent recipe steps",
          control_type: "text-area",
          optional: false,
          sticky: true,
        },
        {
          name: "decision_model",
          hint: "Input the DMN Model content to be processed as data for use in subsequent steps",
          control_type: "text",
          optional: false,
          sticky: true,
        },
      ],

      input_fields: lambda do |object_definitions, connection, config_fields|
        object_definitions["execute_dmn_input"]
      end,

      execute: lambda do |connection, input, _input_schema, _output_schema|
        params = {
          "decision_model": input["decision_model"].encode_base64,
          "decision_id": input["decision_id"],
          "decision_variables": input["decision_variables"].present? ? input["decision_variables"].map do |variable|
            { name: variable.first(), value: variable.last() }
          end : [],
        }

        post("http://localhost/ext/#{connection["profile"]}/executeDmn", params)
          .headers('X-Workato-Connector': "enforce", "Content-type": "application/json; charset=utf-8")
      end,

      output_fields: lambda do |object_definitions, connection, config_fields|
        object_definitions["execute_dmn_output"]
      end,

      sample_output: lambda do |connection, input|
      end,
    },
  },

  methods: {
    validate_decision_model: lambda do |dmn_sample|
      information_requirements = dmn_sample.from_xml.dig("definitions", 0, "decision").pluck("informationRequirement")
      information_requirements.each do |info|
        if info.pluck("requiredDecision").compact.present?
          error("DMN Evaluator does not support required/dependent decisions.  Remove the dependency and call each decision with individual actions.")
        end
      end
    end,

    get_required_decisions: lambda do |dmn_sample, decision_id|
      decision = dmn_sample.from_xml.dig("definitions", 0, "decision").where("@id": decision_id).first()
      required_decisions = decision["informationRequirement"]&.map do |info|
        if info["requiredDecision"].present?
          info["requiredDecision"]&.map do |req|
            req["@href"].gsub("#", "")
          end
        end
      end
      required_decisions&.compact
    end,

    get_decisions: lambda do |dmn_sample|
      dmn_sample.from_xml.dig("definitions", 0, "decision").pluck("@name", "@id")
    end,

    get_input_variables: lambda do |dmn_sample, decision_id|
      decision = dmn_sample.from_xml.dig("definitions", 0, "decision").where("@id": decision_id).first()

      schema = decision["decisionTable"].first()["input"]&.map do |field|
        inputExpression = field.dig("inputExpression", 0)

        # Camunda supports dots in the variable names, this code replace them for the variable input
        # and later converts them back before calling the API
        input_name = inputExpression.dig("text", 0, "content!")
        error("DMN Evaluator does not support nested variables e.g. application.client.age, rename the variable to remove the nested attributes e.g. age") if input_name.index(/[^[:word:]]/) != nil

        case inputExpression["@typeRef"]
        when "string"
          {
            name: input_name,
            label: field["@label"],
            control_type: "text",
            type: "string",
            sticky: true,
          }
        when "boolean"
          {
            name: input_name,
            label: field["@label"],
            control_type: "checkbox",
            toggle_hint: "Select a value",
            sticky: true,
            toggle_field: {
              name: input_name,
              label: field["@label"],
              toggle_hint: "Enter a value",
              type: :string,
              control_type: "text",
              optional: false,
            },
          }
        when "integer"
          {
            name: input_name,
            label: field["@label"],
            control_type: "integer",
            type: "integer",
            sticky: true,
          }
        when "long"
          {
            name: input_name,
            label: field["@label"],
            control_type: "number",
            type: "number",
            sticky: true,
          }
        when "double"
          {
            name: input_name,
            label: field["@label"],
            control_type: "number",
            type: "number",
            sticky: true,
          }
        when "date"
          {
            name: input_name,
            label: field["@label"],
            control_type: "date_time",
            type: "date_time",
            sticky: true,
          }
        end
      end
      schema&.compact
    end,

    get_output_variables: lambda do |dmn_sample, decision_id|
      decision = dmn_sample.from_xml.dig("definitions", 0, "decision").where("@id": decision_id).first()

      schema = decision["decisionTable"].first()["output"]&.compact&.map do |field|
        output_name = field["@name"]

        case field["@typeRef"]
        when "string"
          {
            name: output_name,
            label: field["@label"],
            control_type: "text",
            type: "string",
          }
        when "boolean"
          {
            name: output_name,
            label: field["@label"],
            control_type: "checkbox",
          }
        when "integer"
          {
            name: output_name,
            label: field["@label"],
            control_type: "integer",
            type: "integer",
          }
        when "long"
          {
            name: output_name,
            label: field["@label"],
            control_type: "number",
            type: "number",
          }
        when "double"
          {
            name: output_name,
            label: field["@label"],
            control_type: "number",
            type: "number",
          }
        when "date"
          {
            name: output_name,
            label: field["@label"],
            control_type: "date_time",
            type: "date_time",
          }
        end
      end
      schema&.compact
    end,
  },
}
