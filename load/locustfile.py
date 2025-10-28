from locust import HttpUser, task, between

class WebUser(HttpUser):
    wait_time = between(1, 2.5)

    @task
    def login(self):
        # Adjust payload to your app's expected creds if needed
        self.client.post("/login", json={"username":"user","password":"password"})