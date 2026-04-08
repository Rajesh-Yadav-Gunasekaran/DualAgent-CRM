# DualAgent CRM: Salesforce + AWS Agentic Lead Execution System
Dual Agents - Agentforce and Bedrock help prioritize leads by providing SLAs based on Lead inquiry type, request, workload of agents, and also provides touches on how to contact the leads.

## Overview

This project demonstrates an agentic AI architecture where two AI layers collaborate on every lead:

- Decision Layer → Salesforce Agentforce
- Execution Layer → AWS Bedrock

Instead of using AI as a single black box, the system separates decision-making from execution, enabling control, predictability, and real-world alignment.

---

## How It Works

1. Lead enters via Web-to-Lead
2. Record-triggered Flow assigns SLA based on Inquiry Type
3. Scheduled Path (1 min) triggers evaluation
4. Agentforce evaluates:
   - SLA urgency
   - Inquiry Type (intent)
   - Context (company, notes)
   - Current workload state

5. Agentforce outputs:
   - Priority Bucket (NOW / TODAY / NURTURE)
   - Next Action (CALL / EMAIL)
   - Talking Points
   - Reason Summary

6. Async orchestration:
   - Invocable Apex → Queueable Apex

7. AWS Execution:
   - Apex callout → API Gateway → Lambda → Bedrock
   - Generates 3-touch outreach sequence

8. Data stored in:
   - Lead fields (decision)
   - Lead_Outreach_Draft__c (execution)

9. LWC displays:
   - AI decision + outreach plan

---

## Key Design Decisions

- Separation of AI layers:
  - Agentforce → decision intelligence
  - Bedrock → execution intelligence

- Prompt-driven architecture:
  - Used prompt templates instead of agent abstractions
  - Ensures predictable and controllable outputs

- Async orchestration:
  - Queueable Apex used to avoid timeouts and scale processing

- Real-world alignment:
  - SLA-driven prioritization
  - Workload impacts future decisions (post-SLA breach)

---

## Tech Stack

- Salesforce:
  - Record-Triggered Flows
  - Scheduled Paths
  - Apex (Invocable + Queueable)
  - Lightning Web Components (LWC)
  - Agentforce Prompt Templates

- AWS:
  - API Gateway
  - Lambda (Python)
  - Bedrock Runtime (Nova / Claude)

---

## Repository Structure

force-app/ → Salesforce metadata (Apex, LWC, Flows)
aws/lambda/ → AWS Lambda function
docs/ → Architecture, flow diagrams, prompts

---

## Prompts

- Agentforce prompt → /docs/prompts/agentforce_prompt.txt
- AWS prompt → defined inside Lambda

---

## What This Demonstrates

- Multi-AI system orchestration
- Prompt engineering for controlled AI behavior
- Async architecture in enterprise systems
- Real-world CRM decision modeling using AI

---

## Future Enhancements

- Dynamic sequencing based on engagement
- Feedback loop into Agentforce decisions
- Multi-rep workload balancing

---

## Author

Rajesh Yadav Gunasekaran  
Salesforce | AI | AWS Bedrock | Product Engineering
