from django.http import HttpResponse
from django.urls import path


def index(_request):
    return HttpResponse('Django dynamic web app')


urlpatterns = [
    path('', index),
]
