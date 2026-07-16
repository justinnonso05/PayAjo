def calculate_risk_score(member_id: str) -> dict:
    """
    Calculate the risk score based on:
    - Punctuality
    - Consistency streak
    - Completion rate
    - Tenure
    - Group-relative standing
    """
    # TODO: Implement the PRD risk score logic
    return {
        "score": 85,
        "category": "Low risk",
        "factors": {
            "punctuality": 90,
            "streak": 80,
            "completion": 100,
            "tenure": 50,
            "relative": 95
        }
    }
