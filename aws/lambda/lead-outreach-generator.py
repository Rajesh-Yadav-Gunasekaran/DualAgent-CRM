import json
import boto3

bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

MODEL_ID = "amazon.nova-micro-v1:0"

def build_prompt(payload):
    lead = payload.get("lead", {})
    rec = payload.get("agentforce_recommendation", {})

    return f"""
You are generating outreach sequences for a sales rep.

IMPORTANT RULES:
- Do NOT change next_action or priority_bucket.
- Use them as the source of truth.
- Generate outreach content ONLY.
- Keep emails under 120 words.
- Return ONLY valid JSON.
- Do not wrap output in markdown or code fences.
- Escape all double quotes inside text values.
- Escape line breaks properly inside JSON strings.
- Output must be parseable by Python json.loads().

CRITICAL ENFORCEMENT RULES:

- Touch 1 channel MUST EXACTLY match next_action.
- If next_action = CALL → Touch 1 MUST be CALL.
- If next_action = EMAIL → Touch 1 MUST be EMAIL.

- If next_action = NURTURE:
  - Do NOT use CALL for any touch.
  - All touches should be EMAIL.
  - Content must be soft, informational, and non-aggressive.

- For non-NURTURE cases:
  - Use a realistic sequence pattern:
    - If CALL → CALL, EMAIL, CALL
    - If EMAIL → EMAIL, EMAIL, CALL

Lead:
Name: {lead.get('name', '')}
Company: {lead.get('company', '')}
Title: {lead.get('title', '')}
Description: {lead.get('description', '')}

Recommendation:
Priority: {rec.get('priority_bucket', '')}
Next Action: {rec.get('next_action', '')}
Talking Points: {json.dumps(rec.get('talking_points', []))}
Reasons: {json.dumps(rec.get('reason_summary', []))}

Generate JSON EXACTLY in this format:

{{
  "sequence_version": "v1",
  "items": [
    {{
      "touch": 1,
      "channel": "",
      "send_offset_days": 0,
      "subject_options": ["", ""],
      "body_professional": "",
      "body_executive": "",
      "body_friendly": "",
      "call_opener": "",
      "voicemail": "",
      "fallback_email_subject": "",
      "fallback_email_body": ""
    }},
    {{
      "touch": 2,
      "channel": "",
      "send_offset_days": 2,
      "subject_options": ["", ""],
      "body_professional": "",
      "body_executive": "",
      "body_friendly": "",
      "call_opener": "",
      "voicemail": "",
      "fallback_email_subject": "",
      "fallback_email_body": ""
    }},
    {{
      "touch": 3,
      "channel": "",
      "send_offset_days": 5,
      "subject_options": ["", ""],
      "body_professional": "",
      "body_executive": "",
      "body_friendly": "",
      "call_opener": "",
      "voicemail": "",
      "fallback_email_subject": "",
      "fallback_email_body": ""
    }}
  ]
}}
"""

def normalize_json_text(text):
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()

def lambda_handler(event, context):
    try:
        raw_body = event.get("body", "{}")
        payload = json.loads(raw_body) if isinstance(raw_body, str) else raw_body

        prompt = build_prompt(payload)

        response = bedrock.invoke_model(
            modelId=MODEL_ID,
            contentType="application/json",
            accept="application/json",
            body=json.dumps({
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "text": prompt
                }
            ]
        }
    ],
    "inferenceConfig": {
        "maxTokens": 1400,
        "temperature": 0.2
    }
})
        )

        response_body = json.loads(response["body"].read().decode("utf-8"))
        model_text = response_body["output"]["message"]["content"][0]["text"]
        model_text = normalize_json_text(model_text)
        model_text = model_text.replace("\\'", "'")

        try:
            parsed = json.loads(model_text)
        except Exception as parse_error:
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "success": False,
                    "error": f"JSON parse failed: {str(parse_error)}",
                    "raw_model_output": model_text
                })
            }

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(parsed)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        }