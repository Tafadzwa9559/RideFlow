from django.db import models


class OperationFence(models.Model):
    id = models.CharField(primary_key=True, db_column='_id', max_length=200)
    revision = models.PositiveBigIntegerField(default=0)

    class Meta:
        db_table = 'trivia_operation_fences'
