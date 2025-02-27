from bson.json_util import dumps
from ..models.nosql_models import orders_collection

async def stream_order_changes():
    """
    Asynchronously listens for changes in the orders collection and yields each change as a JSON string.
    """
    pipeline = []  # Optionally add filtering criteria here.
    async with orders_collection.watch(pipeline) as change_stream:
        async for change in change_stream:
            # Convert BSON to JSON string for easier consumption
            yield dumps(change)
