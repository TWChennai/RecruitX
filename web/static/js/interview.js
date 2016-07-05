export var Interview = {
  signup: function(id, api_key) {
    $.ajax({
      url: "/panelists",
      method: 'POST',
      data: JSON.stringify({
       "interview_panelist": {
         "interview_id": id,
         "panelist_login_name": $.cookie("username"),
         "panelist_experience": "11",
         "panelist_role": "Dev"
       }
     }),
      success: function(response) {
        window.location = '/homepage';
      },
      headers: {
        "Authorization": api_key,
        "Content-Type": "application/json"
      }
    });
  }
};
